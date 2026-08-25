package com.zthz.meeting.modules.admin.recordings;

import com.zthz.meeting.modules.admin.meetings.MeetingMemberRepository;
import java.nio.file.Files;
import java.nio.file.Path;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RecordingDownloadService {

    private final RecordingRepository recordingRepository;
    private final MeetingMemberRepository meetingMemberRepository;
    private final Path storageRoot;

    public RecordingDownloadService(
            RecordingRepository recordingRepository,
            MeetingMemberRepository meetingMemberRepository,
            @Value("${app.recording.storage-path:/data/recordings}") String storagePath
    ) {
        this.recordingRepository = recordingRepository;
        this.meetingMemberRepository = meetingMemberRepository;
        this.storageRoot = Path.of(storagePath).toAbsolutePath().normalize();
    }

    @Transactional(readOnly = true)
    public DownloadableRecording requireForUser(Long id, String account, boolean admin) {
        RecordingEntity recording = recordingRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("录制不存在"));
        if (!admin && !meetingMemberRepository.existsByMeetingIdAndUserAccount(recording.getMeeting().getId(), account)) {
            throw new IllegalArgumentException("无权下载此录制");
        }
        if (!"COMPLETED".equals(recording.getStatus()) || recording.getFilePath() == null) {
            throw new IllegalArgumentException("录制文件尚未就绪");
        }
        Path file = Path.of(recording.getFilePath()).toAbsolutePath().normalize();
        if (!file.startsWith(storageRoot) || !Files.isRegularFile(file)) {
            throw new IllegalArgumentException("录制文件不存在");
        }
        return new DownloadableRecording(new FileSystemResource(file), recording.getFileName());
    }

    public record DownloadableRecording(Resource resource, String fileName) {}
}
