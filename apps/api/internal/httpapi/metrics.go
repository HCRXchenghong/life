package httpapi

import (
	"context"
	"database/sql"
	"math"
	"os"
	"runtime"
	"strings"
	"time"

	"github.com/shirou/gopsutil/v4/cpu"
	"github.com/shirou/gopsutil/v4/disk"
	"github.com/shirou/gopsutil/v4/host"
	"github.com/shirou/gopsutil/v4/mem"
)

type serverMetrics struct {
	ID                    string    `json:"id"`
	Name                  string    `json:"name"`
	Hostname              string    `json:"hostname"`
	System                string    `json:"system"`
	SystemLabel           string    `json:"systemLabel"`
	Architecture          string    `json:"architecture"`
	Status                string    `json:"status"`
	CPUPercent            float64   `json:"cpuPercent"`
	MemoryPercent         float64   `json:"memoryPercent"`
	MemoryUsedBytes       uint64    `json:"memoryUsedBytes"`
	MemoryTotalBytes      uint64    `json:"memoryTotalBytes"`
	DiskPercent           float64   `json:"diskPercent"`
	DiskUsedBytes         uint64    `json:"diskUsedBytes"`
	DiskTotalBytes        uint64    `json:"diskTotalBytes"`
	DatabasePercent       float64   `json:"databasePercent"`
	DatabaseUsedBytes     uint64    `json:"databaseUsedBytes"`
	DatabaseCapacityBytes uint64    `json:"databaseCapacityBytes"`
	UpdatedAt             time.Time `json:"updatedAt"`
}

func (s *Server) collectServerMetrics(ctx context.Context) serverMetrics {
	result := serverMetrics{
		ID: "daylink-primary", Name: "Daylink 主服务", Architecture: runtime.GOARCH,
		Status: "online", UpdatedAt: time.Now().UTC(),
	}
	if info, err := host.InfoWithContext(ctx); err == nil {
		result.Hostname = info.Hostname
		result.System, result.SystemLabel = normalizeSystem(info.OS, info.Platform)
	}
	if result.Hostname == "" {
		result.Hostname, _ = os.Hostname()
	}
	if result.System == "" {
		result.System, result.SystemLabel = normalizeSystem(runtime.GOOS, "")
	}
	if usage, err := cpu.PercentWithContext(ctx, 150*time.Millisecond, false); err == nil && len(usage) > 0 {
		result.CPUPercent = normalizedPercent(usage[0])
	}
	if memory, err := mem.VirtualMemoryWithContext(ctx); err == nil {
		result.MemoryPercent = normalizedPercent(memory.UsedPercent)
		result.MemoryUsedBytes = memory.Used
		result.MemoryTotalBytes = memory.Total
	}
	if storage, err := disk.UsageWithContext(ctx, primaryDiskPath()); err == nil {
		result.DiskPercent = normalizedPercent(storage.UsedPercent)
		result.DiskUsedBytes = storage.Used
		result.DiskTotalBytes = storage.Total
	}
	result.DatabaseUsedBytes = s.databaseFootprint(ctx)
	result.DatabaseCapacityBytes = result.DiskTotalBytes
	if result.DatabaseCapacityBytes > 0 {
		result.DatabasePercent = normalizedPercent(float64(result.DatabaseUsedBytes) / float64(result.DatabaseCapacityBytes) * 100)
	}
	return result
}

func (s *Server) databaseFootprint(ctx context.Context) uint64 {
	var size sql.NullInt64
	err := s.db.QueryRowContext(ctx, `SELECT COALESCE(SUM(data_length + index_length), 0)
		FROM information_schema.tables WHERE table_schema = DATABASE()`).Scan(&size)
	if err != nil || !size.Valid || size.Int64 < 0 {
		return 0
	}
	return uint64(size.Int64)
}

func normalizeSystem(operatingSystem, platform string) (string, string) {
	value := strings.ToLower(strings.TrimSpace(platform))
	operatingSystem = strings.ToLower(strings.TrimSpace(operatingSystem))
	switch {
	case operatingSystem == "windows" || strings.Contains(value, "windows"):
		return "windows", "Windows"
	case operatingSystem == "darwin" || value == "macos" || strings.Contains(value, "mac os"):
		return "macos", "macOS"
	case value == "ubuntu" || strings.Contains(value, "ubuntu"):
		return "ubuntu", "Ubuntu"
	case operatingSystem == "linux":
		return "linux", "Linux"
	default:
		return operatingSystem, operatingSystem
	}
}

func primaryDiskPath() string {
	if runtime.GOOS == "windows" {
		if drive := strings.TrimSpace(os.Getenv("SystemDrive")); drive != "" {
			return drive + `\`
		}
		return `C:\`
	}
	return "/"
}

func normalizedPercent(value float64) float64 {
	if math.IsNaN(value) || math.IsInf(value, 0) || value < 0 {
		return 0
	}
	if value > 100 {
		value = 100
	}
	return math.Round(value*10) / 10
}
