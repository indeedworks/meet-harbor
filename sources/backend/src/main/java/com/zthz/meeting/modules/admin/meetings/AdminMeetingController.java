package com.zthz.meeting.modules.admin.meetings;

import com.zthz.meeting.common.ApiResponse;
import com.zthz.meeting.modules.admin.meetings.AdminMeetingService.ForceStopMeetingResponse;
import com.zthz.meeting.modules.admin.meetings.AdminMeetingService.HistoryMeetingResponse;
import com.zthz.meeting.modules.admin.meetings.AdminMeetingService.OnlineMeetingResponse;
import com.zthz.meeting.modules.logs.OperationLogService;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/meetings")
public class AdminMeetingController {

    private final AdminMeetingService adminMeetingService;
    private final OperationLogService operationLogService;

    public AdminMeetingController(AdminMeetingService adminMeetingService, OperationLogService operationLogService) {
        this.adminMeetingService = adminMeetingService;
        this.operationLogService = operationLogService;
    }

    @GetMapping("/online")
    public ApiResponse<List<OnlineMeetingResponse>> onlineMeetings() {
        return ApiResponse.ok(adminMeetingService.listOnlineMeetings());
    }

    @GetMapping("/history")
    public ApiResponse<List<HistoryMeetingResponse>> historyMeetings() {
        return ApiResponse.ok(adminMeetingService.listHistoryMeetings());
    }

    @PostMapping("/{meetingNo}/force-stop")
    public ApiResponse<ForceStopMeetingResponse> forceStopMeeting(
            @PathVariable String meetingNo,
            HttpServletRequest httpRequest
    ) {
        ForceStopMeetingResponse response = adminMeetingService.forceStopMeeting(meetingNo);
        operationLogService.record(
                "FORCE_STOP_MEETING",
                "MEETING",
                null,
                "{\"meetingNo\":\"" + meetingNo + "\",\"closedSessions\":" + response.closedSessions() + "}",
                httpRequest
        );
        return ApiResponse.ok(response);
    }
}
