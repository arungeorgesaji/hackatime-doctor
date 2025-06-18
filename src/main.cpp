#include "hackatime_doctor.h"
#include <iostream>
#include <algorithm>

void run_hackatime_doctor() {
    std::cout << COLOR_BLUE << "⚕️ HackaTime Doctor - Checking your development environment...\n" << COLOR_RESET;
    
    std::vector<CheckResult> results = {
        check_git_installed(),
        check_node_installed(),
        check_folder_structure(),
        check_api_tokens()
    };
    
    print_summary(results);
    
    bool has_failures = std::any_of(results.begin(), results.end(), 
        [](const auto& result) { return !result.success; });
    
    if (has_failures) suggest_debug_tips(results);  
}

int main() {
    run_hackatime_doctor();
    return 0;
}
