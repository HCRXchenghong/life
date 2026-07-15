package httpapi

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

const maximumArtifactBytes = 24 << 20

type artifactRequest struct {
	Kind       string          `json:"kind"`
	Title      string          `json:"title"`
	Paragraphs []string        `json:"paragraphs,omitempty"`
	Sheets     []artifactSheet `json:"sheets,omitempty"`
	Slides     []artifactSlide `json:"slides,omitempty"`
}

type artifactSheet struct {
	Name string     `json:"name"`
	Rows [][]string `json:"rows"`
}

type artifactSlide struct {
	Title   string   `json:"title"`
	Bullets []string `json:"bullets"`
}

type generatedArtifact struct {
	Content     []byte
	ContentType string
	Extension   string
}

type packagePart struct {
	Name string
	XML  string
}

func (s *Server) handleAssistantArtifact(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "assistant_artifacts", identity.AccountID, 30); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "文档生成过于频繁，请稍后重试")
		return
	}
	var input artifactRequest
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "文档内容无效")
		return
	}
	artifact, err := generateOfficeArtifact(input)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if len(artifact.Content) > maximumArtifactBytes {
		writeError(w, http.StatusRequestEntityTooLarge, "artifact_too_large", "生成的文档过大")
		return
	}
	auditID, _ := security.RandomID()
	s.audit(r.Context(), "app:"+identity.AccountID, "artifact.generate", "office_"+input.Kind, auditID, "allowed", "medium")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", artifact.ContentType)
	w.Header().Set("Content-Disposition", `attachment; filename="daylink-document.`+artifact.Extension+`"`)
	w.Header().Set("Content-Length", strconv.Itoa(len(artifact.Content)))
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(artifact.Content)
}

func generateOfficeArtifact(input artifactRequest) (generatedArtifact, error) {
	input.Title = strings.TrimSpace(input.Title)
	if err := validateArtifactText(input.Title, 1, 160); err != nil {
		return generatedArtifact{}, errors.New("文档标题无效")
	}
	switch input.Kind {
	case "docx":
		content, err := generateDOCX(input.Title, input.Paragraphs)
		return generatedArtifact{content, "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "docx"}, err
	case "xlsx":
		content, err := generateXLSX(input.Sheets)
		return generatedArtifact{content, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "xlsx"}, err
	case "pptx":
		content, err := generatePPTX(input.Title, input.Slides)
		return generatedArtifact{content, "application/vnd.openxmlformats-officedocument.presentationml.presentation", "pptx"}, err
	default:
		return generatedArtifact{}, errors.New("不支持的文档类型")
	}
}

func generateDOCX(title string, paragraphs []string) ([]byte, error) {
	if len(paragraphs) == 0 || len(paragraphs) > 200 {
		return nil, errors.New("Word 正文数量无效")
	}
	var body strings.Builder
	body.WriteString(wordParagraph(title, true))
	for _, paragraph := range paragraphs {
		if err := validateArtifactText(paragraph, 0, 5_000); err != nil {
			return nil, errors.New("Word 正文内容无效")
		}
		body.WriteString(wordParagraph(paragraph, false))
	}
	body.WriteString(`<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>`)
	return writeOfficePackage([]packagePart{
		{"[Content_Types].xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>`},
		{"_rels/.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>`},
		{"word/document.xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>` + body.String() + `</w:body></w:document>`},
	})
}

func wordParagraph(text string, title bool) string {
	properties := ""
	if title {
		properties = `<w:rPr><w:b/><w:sz w:val="36"/></w:rPr>`
	}
	return `<w:p><w:r>` + properties + `<w:t xml:space="preserve">` + escapeXML(text) + `</w:t></w:r></w:p>`
}

func generateXLSX(sheets []artifactSheet) ([]byte, error) {
	if len(sheets) == 0 || len(sheets) > 10 {
		return nil, errors.New("表格工作表数量无效")
	}
	parts := []packagePart{
		{"_rels/.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`},
	}
	var overrides, workbook, relationships strings.Builder
	seenNames := make(map[string]bool, len(sheets))
	totalCells := 0
	for sheetIndex, sheet := range sheets {
		name := strings.TrimSpace(sheet.Name)
		if err := validateSheetName(name, seenNames); err != nil {
			return nil, err
		}
		seenNames[strings.ToLower(name)] = true
		if len(sheet.Rows) > 1_000 {
			return nil, errors.New("单个工作表行数过多")
		}
		var rows strings.Builder
		for rowIndex, row := range sheet.Rows {
			if len(row) > 50 {
				return nil, errors.New("单个工作表列数过多")
			}
			totalCells += len(row)
			if totalCells > 10_000 {
				return nil, errors.New("表格单元格数量过多")
			}
			rows.WriteString(`<row r="` + strconv.Itoa(rowIndex+1) + `">`)
			for columnIndex, value := range row {
				if err := validateArtifactText(value, 0, 4_000); err != nil {
					return nil, errors.New("表格单元格内容无效")
				}
				rows.WriteString(`<c r="` + spreadsheetColumn(columnIndex+1) + strconv.Itoa(rowIndex+1) + `" t="inlineStr"><is><t xml:space="preserve">` + escapeXML(value) + `</t></is></c>`)
			}
			rows.WriteString(`</row>`)
		}
		id := strconv.Itoa(sheetIndex + 1)
		overrides.WriteString(`<Override PartName="/xl/worksheets/sheet` + id + `.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`)
		workbook.WriteString(`<sheet name="` + escapeXML(name) + `" sheetId="` + id + `" r:id="rId` + id + `"/>`)
		relationships.WriteString(`<Relationship Id="rId` + id + `" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet` + id + `.xml"/>`)
		parts = append(parts, packagePart{"xl/worksheets/sheet" + id + ".xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>` + rows.String() + `</sheetData></worksheet>`})
	}
	parts = append(parts,
		packagePart{"[Content_Types].xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>` + overrides.String() + `</Types>`},
		packagePart{"xl/workbook.xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>` + workbook.String() + `</sheets></workbook>`},
		packagePart{"xl/_rels/workbook.xml.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` + relationships.String() + `</Relationships>`},
	)
	return writeOfficePackage(parts)
}

func generatePPTX(title string, slides []artifactSlide) ([]byte, error) {
	if len(slides) == 0 || len(slides) > 50 {
		return nil, errors.New("PPT 页数无效")
	}
	parts := []packagePart{
		{"_rels/.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/></Relationships>`},
		{"ppt/slideMasters/slideMaster1.xml", slideMasterXML},
		{"ppt/slideMasters/_rels/slideMaster1.xml.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>`},
		{"ppt/slideLayouts/slideLayout1.xml", slideLayoutXML},
		{"ppt/slideLayouts/_rels/slideLayout1.xml.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>`},
		{"ppt/theme/theme1.xml", themeXML},
	}
	var overrides, slideIDs, relationships strings.Builder
	relationships.WriteString(`<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>`)
	for index, slide := range slides {
		if err := validateArtifactText(slide.Title, 1, 240); err != nil || len(slide.Bullets) > 30 {
			return nil, errors.New("PPT 页面内容无效")
		}
		for _, bullet := range slide.Bullets {
			if err := validateArtifactText(bullet, 0, 1_000); err != nil {
				return nil, errors.New("PPT 页面内容无效")
			}
		}
		id := strconv.Itoa(index + 1)
		relationID := strconv.Itoa(index + 2)
		overrides.WriteString(`<Override PartName="/ppt/slides/slide` + id + `.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>`)
		slideIDs.WriteString(`<p:sldId id="` + strconv.Itoa(256+index) + `" r:id="rId` + relationID + `"/>`)
		relationships.WriteString(`<Relationship Id="rId` + relationID + `" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide` + id + `.xml"/>`)
		parts = append(parts,
			packagePart{"ppt/slides/slide" + id + ".xml", presentationSlideXML(slide)},
			packagePart{"ppt/slides/_rels/slide" + id + ".xml.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>`},
		)
	}
	parts = append(parts,
		packagePart{"[Content_Types].xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/><Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/><Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>` + overrides.String() + `</Types>`},
		packagePart{"ppt/presentation.xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst><p:sldIdLst>` + slideIDs.String() + `</p:sldIdLst><p:sldSz cx="12192000" cy="6858000" type="screen16x9"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>`},
		packagePart{"ppt/_rels/presentation.xml.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` + relationships.String() + `</Relationships>`},
		packagePart{"docProps/core.xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>` + escapeXML(title) + `</dc:title></cp:coreProperties>`},
	)
	return writeOfficePackage(parts)
}

func presentationSlideXML(slide artifactSlide) string {
	var bullets strings.Builder
	for _, bullet := range slide.Bullets {
		bullets.WriteString(`<a:p><a:pPr lvl="0"><a:buChar char="•"/></a:pPr><a:r><a:rPr lang="zh-CN" sz="2200"/><a:t>` + escapeXML(bullet) + `</a:t></a:r><a:endParaRPr lang="zh-CN" sz="2200"/></a:p>`)
	}
	return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree>` + presentationGroupXML + `<p:sp><p:nvSpPr><p:cNvPr id="2" name="标题"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="685800" y="457200"/><a:ext cx="10820400" cy="1143000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="zh-CN" sz="3000" b="1"/><a:t>` + escapeXML(slide.Title) + `</a:t></a:r><a:endParaRPr lang="zh-CN" sz="3000"/></a:p></p:txBody></p:sp><p:sp><p:nvSpPr><p:cNvPr id="3" name="正文"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="914400" y="1828800"/><a:ext cx="10363200" cy="4114800"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap="square"/><a:lstStyle/>` + bullets.String() + `</p:txBody></p:sp></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>`
}

const presentationGroupXML = `<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>`

const slideMasterXML = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree>` + presentationGroupXML + `</p:spTree></p:cSld><p:clrMap accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" bg1="lt1" bg2="lt2" folHlink="folHlink" hlink="hlink" tx1="dk1" tx2="dk2"/><p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>`

const slideLayoutXML = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank"><p:cSld name="空白"><p:spTree>` + presentationGroupXML + `</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>`

const themeXML = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Daylink"><a:themeElements><a:clrScheme name="Daylink"><a:dk1><a:srgbClr val="101828"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="344054"/></a:dk2><a:lt2><a:srgbClr val="F2F4F7"/></a:lt2><a:accent1><a:srgbClr val="3370FF"/></a:accent1><a:accent2><a:srgbClr val="7F56D9"/></a:accent2><a:accent3><a:srgbClr val="12B76A"/></a:accent3><a:accent4><a:srgbClr val="F79009"/></a:accent4><a:accent5><a:srgbClr val="06AED4"/></a:accent5><a:accent6><a:srgbClr val="EE46BC"/></a:accent6><a:hlink><a:srgbClr val="0563C1"/></a:hlink><a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme><a:fontScheme name="Daylink"><a:majorFont><a:latin typeface="Aptos Display"/><a:ea typeface="Microsoft YaHei"/><a:cs typeface="Arial"/></a:majorFont><a:minorFont><a:latin typeface="Aptos"/><a:ea typeface="Microsoft YaHei"/><a:cs typeface="Arial"/></a:minorFont></a:fontScheme><a:fmtScheme name="Daylink"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>`

func writeOfficePackage(parts []packagePart) ([]byte, error) {
	var output bytes.Buffer
	archive := zip.NewWriter(&output)
	for _, part := range parts {
		header := &zip.FileHeader{Name: part.Name, Method: zip.Deflate}
		writer, err := archive.CreateHeader(header)
		if err != nil {
			return nil, err
		}
		if _, err := writer.Write([]byte(part.XML)); err != nil {
			return nil, err
		}
	}
	if err := archive.Close(); err != nil {
		return nil, err
	}
	return output.Bytes(), nil
}

func validateArtifactText(value string, minimum, maximum int) error {
	if !utf8.ValidString(value) {
		return errors.New("invalid UTF-8")
	}
	count := utf8.RuneCountInString(value)
	if count < minimum || count > maximum {
		return errors.New("invalid text length")
	}
	for _, character := range value {
		if character != '\t' && character != '\n' && character != '\r' && character < 0x20 {
			return errors.New("invalid XML character")
		}
	}
	return nil
}

func validateSheetName(name string, seen map[string]bool) error {
	if err := validateArtifactText(name, 1, 31); err != nil || strings.ContainsAny(name, `[]:*?/\`) || seen[strings.ToLower(name)] {
		return errors.New("工作表名称无效或重复")
	}
	return nil
}

func spreadsheetColumn(column int) string {
	var output string
	for column > 0 {
		column--
		output = string(rune('A'+column%26)) + output
		column /= 26
	}
	return output
}

func escapeXML(value string) string {
	var output bytes.Buffer
	if err := xml.EscapeText(&output, []byte(value)); err != nil {
		return fmt.Sprintf("%q", value)
	}
	return output.String()
}
