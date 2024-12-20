#pragma once

#include "ComparisonFunction.hpp"
#include "DepthWriteMask.hpp"



#include "DepthStencilOperation.hpp"


namespace My {
    struct DepthStencilState {
        bool	enable;

        ComparisonFunction::Enum	depth_function;

        DepthWriteMask::Enum	depth_write_mask;

        bool	stencil_enable;

        char	stencil_read_mask;

        char	stencil_write_mask;

        DepthStencilOperation	front_face;

        DepthStencilOperation	back_face;


        void reflectMembers() {
            ImGui::Checkbox( "enable", &enable );
            ImGui::Combo( "depth_function", (int32_t*)&depth_function, ComparisonFunction::s_value_names, ComparisonFunction::Count );

            ImGui::Combo( "depth_write_mask", (int32_t*)&depth_write_mask, DepthWriteMask::s_value_names, DepthWriteMask::Count );

            ImGui::Checkbox( "stencil_enable", &stencil_enable );
            ImGui::InputScalar( "stencil_read_mask", ImGuiDataType_S8, &stencil_read_mask );
            ImGui::InputScalar( "stencil_write_mask", ImGuiDataType_S8, &stencil_write_mask );
            ImGui::Text("front_face");
            front_face.reflectMembers();

            ImGui::Text("back_face");
            back_face.reflectMembers();

        }

        void reflectUI() {
            ImGui::Begin("DepthStencilState");
            reflectMembers();
            ImGui::End();
        }
    };
} // namespace My
