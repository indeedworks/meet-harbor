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

@RestController
@RequestMapping("/api/admin/recordings")
public class AdminRecordingController {

    private final AdminRecordingService adminRecordingService;
    private final OperationLogService operationLogService;

    public AdminRecordingController(
            AdminRecordingService adminRecordingService,
            OperationLogService operationLogService
    ) {
        this.adminRecordingService = adminRecordingService;
        this.operationLogService = operationLogService;
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
}
