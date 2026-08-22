package com.zthz.meeting.modules.system;

import com.zthz.meeting.common.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/system")
public class AdminSystemController {

    private final AdminSystemService adminSystemService;

    public AdminSystemController(AdminSystemService adminSystemService) {
        this.adminSystemService = adminSystemService;
    }

    @GetMapping("/overview")
    public ApiResponse<AdminSystemService.SystemOverviewResponse> overview() {
        return ApiResponse.ok(adminSystemService.overview());
    }
}

