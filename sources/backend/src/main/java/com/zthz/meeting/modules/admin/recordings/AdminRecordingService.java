package com.zthz.meeting.modules.admin.recordings;

import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminRecordingService {

    private final RecordingRepository recordingRepository;

    public AdminRecordingService(RecordingRepository recordingRepository) {
        this.recordingRepository = recordingRepository;
    }

    @Transactional(readOnly = true)
    public List<AdminRecordingResponse> listRecordings() {
        return recordingRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(recording -> new AdminRecordingResponse(
                        recording.getId(),
                        recording.getMeeting().getTopic(),
                        recording.getMeeting().getMeetingNo(),
                        recording.getStatus(),
                        recording.getFileName(),
                        recording.getFileSizeBytes(),
                        recording.getCreatedAt(),
                        recording.getExpiredAt()
                ))
                .toList();
    }

    @Transactional
    public void deleteRecording(Long id) {
        RecordingEntity recording = recordingRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("录制不存在"));
        recording.setStatus("DELETED");
        recording.setDeletedAt(OffsetDateTime.now());
        recording.setUpdatedAt(OffsetDateTime.now());
        recordingRepository.save(recording);
    }

    public record AdminRecordingResponse(
            Long id,
            String meetingTopic,
            String meetingNo,
            String status,
            String fileName,
            Long fileSizeBytes,
            OffsetDateTime createdAt,
            OffsetDateTime expiredAt
    ) {
    }
}

