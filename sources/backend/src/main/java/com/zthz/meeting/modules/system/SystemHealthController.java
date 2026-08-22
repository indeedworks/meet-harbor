package com.zthz.meeting.modules.system;

import com.zthz.meeting.common.ApiResponse;
import java.time.OffsetDateTime;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/system")
public class SystemHealthController {

    @GetMapping("/health")
    public ApiResponse<SystemHealthResponse> health() {
        return ApiResponse.ok(new SystemHealthResponse("UP", OffsetDateTime.now()));
    }

    public record SystemHealthResponse(String status, OffsetDateTime serverTime) {
    }
}

