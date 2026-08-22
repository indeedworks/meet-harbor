package com.zthz.meeting.modules.system;

import com.zthz.meeting.modules.admin.meetings.MeetingMemberRepository;
import com.zthz.meeting.modules.admin.meetings.MeetingRepository;
import com.zthz.meeting.modules.admin.recordings.RecordingRepository;
import java.io.File;
import java.lang.management.ManagementFactory;
import java.time.OffsetDateTime;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class AdminSystemService {

    private final MeetingRepository meetingRepository;
    private final MeetingMemberRepository meetingMemberRepository;
    private final RecordingRepository recordingRepository;
    private final String recordingStoragePath;

    public AdminSystemService(
            MeetingRepository meetingRepository,
            MeetingMemberRepository meetingMemberRepository,
            RecordingRepository recordingRepository,
            @Value("${app.recording.storage-path:/data/recordings}") String recordingStoragePath
    ) {
        this.meetingRepository = meetingRepository;
        this.meetingMemberRepository = meetingMemberRepository;
        this.recordingRepository = recordingRepository;
        this.recordingStoragePath = recordingStoragePath;
    }

    public SystemOverviewResponse overview() {
        File storageRoot = storageRoot();
        long totalBytes = storageRoot.getTotalSpace();
        long freeBytes = storageRoot.getFreeSpace();
        long usedBytes = Math.max(0L, totalBytes - freeBytes);
        long recordingUsedBytes = recordingRepository.sumActiveFileSizeBytes();
        OffsetDateTime now = OffsetDateTime.now();

        return new SystemOverviewResponse(
                meetingRepository.countByStatus("IN_PROGRESS"),
                meetingMemberRepository.countOnlineUsers(),
                recordingRepository.countByStatus("RECORDING") + recordingRepository.countByStatus("PROCESSING"),
                recordingUsedBytes,
                totalBytes,
                usedBytes,
                freeBytes,
                recordingUsedBytes,
                recordingRepository.countByExpiredAtBetween(now, now.plusDays(1)),
                cpuUsagePercent(),
                memoryUsagePercent(),
                percent(usedBytes, totalBytes),
                0L,
                "UP",
                "UP",
                "UP",
                OffsetDateTime.now()
        );
    }

    private File storageRoot() {
        File root = new File(recordingStoragePath);
        if (root.exists() || root.mkdirs()) {
            return root;
        }
        return new File(".");
    }

    private double cpuUsagePercent() {
        java.lang.management.OperatingSystemMXBean bean = ManagementFactory.getOperatingSystemMXBean();
        if (bean instanceof com.sun.management.OperatingSystemMXBean osBean) {
            double load = osBean.getCpuLoad();
            if (load >= 0) {
                return round(load * 100);
            }
        }
        return 0;
    }

    private double memoryUsagePercent() {
        Runtime runtime = Runtime.getRuntime();
        long total = runtime.totalMemory();
        long free = runtime.freeMemory();
        return percent(total - free, total);
    }

    private double percent(long value, long total) {
        if (total <= 0) {
            return 0;
        }
        return round(value * 100.0 / total);
    }

    private double round(double value) {
        return Math.round(value * 10.0) / 10.0;
    }

    public record SystemOverviewResponse(
            long currentMeetingCount,
            long currentOnlineUserCount,
            long currentRecordingTaskCount,
            long recordingFileBytes,
            long totalStorageBytes,
            long usedStorageBytes,
            long freeStorageBytes,
            long recordingUsedBytes,
            long expiringRecordingCount,
            double cpuUsagePercent,
            double memoryUsagePercent,
            double diskUsagePercent,
            long bandwidthBytesPerSecond,
            String mediaServiceStatus,
            String recordingServiceStatus,
            String signalingServiceStatus,
            OffsetDateTime serverTime
    ) {
    }
}

