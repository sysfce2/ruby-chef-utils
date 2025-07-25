#
# Authors:: Trevor O (trevoro@joyent.com)
#           Bryan McLellan (btm@loftninjas.org)
#           Matthew Landauer (matthew@openaustralia.org)
#           Ben Rockwood (benr@joyent.com)
# Copyright:: Copyright 2009-2018, Bryan McLellan, Matthew Landauer
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require_relative "../package"
require_relative "../../resource/package"
require_relative "../../mixin/get_source_from_package"

class Chef
  class Provider
    class Package
      class SmartOS < Chef::Provider::Package
        attr_accessor :is_virtual_package

        provides :package, platform: "smartos", target_mode: true
        provides :smartos_package, target_mode: true

        def load_current_resource
          logger.trace("#{new_resource} loading current resource")
          @current_resource = Chef::Resource::Package.new(new_resource.name)
          current_resource.package_name(new_resource.package_name)
          check_package_state(new_resource.package_name)
          current_resource # modified by check_package_state
        end

        def define_resource_requirements
          super

          requirements.assert(:all_actions) do |a|
            a.assertion { !new_resource.environment }
            a.failure_message Chef::Exceptions::Package, "The environment property is not supported for package resources on this platform"
          end
        end

        def check_package_state(name)
          logger.trace("#{new_resource} checking package #{name}")
          version = nil
          info = shell_out!("/opt/local/sbin/pkg_info", "-E", "#{name}*", env: nil, returns: [0, 1])

          if info.stdout
            version = info.stdout[/^#{new_resource.package_name}-(.+)/, 1]
          end

          if version
            current_resource.version(version)
          end
        end

        def candidate_version
          return @candidate_version if @candidate_version

          name = nil
          version = nil
          pkg = shell_out!("/opt/local/bin/pkgin", "se", new_resource.package_name, env: nil, returns: [0, 1])
          pkg.stdout.each_line do |line|
            case line
            when /^#{new_resource.package_name}/
              name, version = line.split(/[; ]/)[0].split(/-([^-]+)$/)
            end
          end
          @candidate_version = version
          version
        end

        def install_package(name, version)
          logger.trace("#{new_resource} installing package #{name} version #{version}")
          package = "#{name}-#{version}"
          out = shell_out!("/opt/local/bin/pkgin", "-y", "install", package, env: nil)
        end

        def upgrade_package(name, version)
          logger.trace("#{new_resource} upgrading package #{name} version #{version}")
          install_package(name, version)
        end

        def remove_package(name, version)
          logger.trace("#{new_resource} removing package #{name} version #{version}")
          package = name.to_s
          out = shell_out!("/opt/local/bin/pkgin", "-y", "remove", package, env: nil)
        end

      end
    end
  end
end
