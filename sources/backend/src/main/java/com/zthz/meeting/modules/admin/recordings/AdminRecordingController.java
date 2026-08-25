package com.zthz.meeting.modules.admin.recordings;

import com.zthz.meeting.common.ApiResponse;
import com.zthz.meeting.modules.admin.recordings.AdminRecordingService.AdminRecordingResponse;
import com.zthz.meeting.modules.logs.OperationLogService;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

@RestController
@RequestMapping("/api/admin/recordings")
public class AdminRecordingController {

    private final AdminRecordingService adminRecordingService;
    private final OperationLogService operationLogService;
    private final RecordingDownloadService recordingDownloadService;

    public AdminRecordingController(
            AdminRecordingService adminRecordingService,
            OperationLogService operationLogService,
            RecordingDownloadService recordingDownloadService
    ) {
        this.adminRecordingService = adminRecordingService;
        this.operationLogService = operationLogService;
        this.recordingDownloadService = recordingDownloadService;
    }

    @GetMapping
    public ApiResponse<List<AdminRecordingResponse>> listRecordings() {
        return ApiResponse.ok(adminRecordingService.listRecordings());
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Void> deleteRecording(@PathVariable Long id, HttpServletRequest httpRequest) {
        adminRecordingService.deleteRecording(id);
        operationLogService.record("DELETE_RECORDING", "RECORDING", id, null, httpRequest);
        return ApiResponse.ok();
    }

    @GetMapping("/{id}/download")
    public ResponseEntity<org.springframework.core.io.Resource> downloadRecording(@PathVariable Long id) {
        RecordingDownloadService.DownloadableRecording download =
                recordingDownloadService.requireForUser(id, "", true);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename(download.fileName(), java.nio.charset.StandardCharsets.UTF_8).build().toString())
                .body(download.resource());
    }
}
