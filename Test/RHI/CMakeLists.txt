if(OS_MACOS OR OS_WINDOWS)
    if(Vulkan_FOUND)
        execute_process(COMMAND git submodule update --init ${MYGE_EXTERNAL_ROOT}/../src/tinyobjloader)
        add_executable(VulkanRHITest VulkanRHITest.cpp)
        target_include_directories(VulkanRHITest PRIVATE ${PROJECT_SOURCE_DIR}/External/src/tinyobjloader)
        target_link_libraries(VulkanRHITest Framework VulkanRHI PlatformInterface)
    endif(Vulkan_FOUND)
endif(OS_MACOS OR OS_WINDOWS)

if(OS_WINDOWS)
    add_executable(D2dRHITest D2dRHITest.cpp)
    target_link_libraries(D2dRHITest Framework D2dRHI PlatformInterface)

    execute_process(COMMAND git submodule update --init ${MYGE_EXTERNAL_ROOT}/../src/tinyobjloader)
    add_executable(D3d12RHITest D3d12RHITest.cpp)
    target_include_directories(D3d12RHITest PRIVATE ${PROJECT_SOURCE_DIR}/External/src/tinyobjloader)
    target_link_libraries(D3d12RHITest Framework D3dRHI PlatformInterface)
endif(OS_WINDOWS)
