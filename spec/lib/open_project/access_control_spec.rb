#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'

RSpec.describe OpenProject::AccessControl do
  def setup_permissions
    OpenProject::AccessControl.map do |map|
      map.permission :no_module_project_permission_with_contract_actions,
                     { dont: :care },
                     permissible_on: :project,
                     require: :member,
                     contract_actions: { foo: :create }
      map.permission :no_module_global_permission,
                     { dont: :care },
                     permissible_on: :global
      map.permission :no_module_project_permission,
                     { dont: :care },
                     permissible_on: :project

      map.project_module :global_module do |mod|
        mod.permission :global_module_global_permission,
                       { dont: :care },
                       permissible_on: :global
      end

      map.project_module :project_module do |mod|
        mod.permission :project_module_project_permission_with_contract_actions,
                       { dont: :care },
                       permissible_on: :project,
                       contract_actions: { bar: %i[create read] },
                       public: true
      end

      map.project_module :mixed_module do |mod|
        mod.permission :mixed_module_project_permission_granted_to_admin,
                       { dont: :care },
                       permissible_on: :project,
                       grant_to_admin: true
        mod.permission :mixed_module_global_permission_with_contract_actions,
                       { dont: :care },
                       permissible_on: :global,
                       contract_actions: { baz: %i[destroy] }
      end

      map.project_module :dependent_module, dependencies: :project_module do |mod|
        mod.permission :dependent_module_project_permission_not_granted_to_admin,
                       { dont: :care },
                       permissible_on: :project,
                       grant_to_admin: false
      end
    end
  end

  describe '.remove_modules_permissions' do
    let!(:all_former_permissions) { described_class.permissions }
    let!(:former_repository_permissions) do
      described_class.modules_permissions(%w[repository])
                     .select { |permission| permission.project_module == :repository }
    end

    subject { described_class }

    def reset_former_permissions_and_clear_caches
      described_class.instance_variable_set(:@mapped_permissions, all_former_permissions)
      described_class.clear_caches
    end

    around do |example|
      described_class.remove_modules_permissions(:repository)

      example.run
    ensure
      raise 'Test outdated. @mapped_permissions is not defined after example run' unless
        described_class.instance_variable_defined?(:@mapped_permissions)

      reset_former_permissions_and_clear_caches
    end

    it 'removes from permissions' do
      expect(subject.permissions)
        .not_to include(former_repository_permissions)
    end

    it 'removes from global permissions' do
      expect(subject.global_permissions)
        .not_to include(former_repository_permissions)
    end

    it 'removes from public permissions' do
      expect(subject.public_permissions)
        .not_to include(former_repository_permissions)
    end

    it 'removes from members-only permissions' do
      expect(subject.members_only_permissions)
        .not_to include(former_repository_permissions)
    end

    it 'removes from loggedin-only permissions' do
      expect(subject.loggedin_only_permissions)
        .not_to include(former_repository_permissions)
    end

    it 'disables repository module' do
      expect(subject.available_project_modules)
        .not_to include(:repository)
    end
  end

  describe '.permissions' do
    subject(:permissions) { described_class.permissions }

    it 'returns an array permissions' do
      expect(permissions)
        .to all(be_instance_of(OpenProject::AccessControl::Permission))
    end

    it 'returns only enabled permissions' do
      expect(permissions)
        .to all(be_enabled)
    end
  end

  describe '.permission' do
    context 'for a project module permission' do
      subject { described_class.permission(:view_work_packages) }

      it 'is a permission' do
        expect(subject)
          .to be_a(OpenProject::AccessControl::Permission)
      end

      it 'is the permission with the queried-for name' do
        expect(subject.name)
          .to eq(:view_work_packages)
      end

      it 'belongs to a project module' do
        expect(subject.project_module)
          .to eq(:work_package_tracking)
      end
    end

    context 'for a non module permission' do
      subject { described_class.permission(:edit_project) }

      it 'is a permission' do
        expect(subject)
          .to be_a(OpenProject::AccessControl::Permission)
      end

      it 'is the permission with the queried-for name' do
        expect(subject.name)
          .to eq(:edit_project)
      end

      it 'does not belong to a project module' do
        expect(subject.project_module)
          .to be_nil
      end

      it 'includes actions' do
        expect(subject.controller_actions)
          .to include('projects/settings/general/show')
      end
    end

    describe '#dependencies' do
      context 'for a permission with a pre-requisite' do
        subject(:dependencies) do
          described_class.permission(:edit_work_packages)
                         .dependencies
        end

        it 'denotes the pre-requisites' do
          expect(dependencies)
            .to contain_exactly(:view_work_packages)
        end
      end

      context 'for a permission without a pre-requisite' do
        subject(:dependencies) do
          described_class.permission(:view_work_packages)
                         .dependencies
        end

        it 'denotes no pre-requisites' do
          expect(dependencies)
            .to be_empty
        end
      end
    end
  end

  describe '.modules' do
    include_context 'with blank access control state'

    before do
      setup_permissions
    end

    subject(:dependencies) do
      described_class.modules
                     .find { _1[:name] == :dependent_module }[:dependencies]
    end

    it 'can store specified dependencies' do
      expect(dependencies)
        .to contain_exactly(:project_module)
    end
  end

  describe '.project_permissions' do
    include_context 'with blank access control state'

    before do
      setup_permissions
    end

    subject(:project_permissions) do
      described_class.project_permissions
    end

    it { expect(project_permissions.size).to eq(5) }

    it do
      expect(project_permissions.map(&:name))
        .to contain_exactly(:no_module_project_permission_with_contract_actions,
                            :no_module_project_permission,
                            :project_module_project_permission_with_contract_actions,
                            :mixed_module_project_permission_granted_to_admin,
                            :dependent_module_project_permission_not_granted_to_admin)
    end
  end

  describe '.global_permissions' do
    include_context 'with blank access control state'

    before do
      setup_permissions
    end

    subject(:global_permissions) do
      described_class.global_permissions
    end

    it { expect(global_permissions.size).to eq(3) }

    it do
      expect(global_permissions.map(&:name))
        .to contain_exactly(:no_module_global_permission,
                            :global_module_global_permission,
                            :mixed_module_global_permission_with_contract_actions)
    end
  end

  describe '.available_project_modules' do
    include_context 'with blank access control state'

    before do
      setup_permissions
    end

    subject(:available_project_modules) do
      described_class.available_project_modules
    end

    it { expect(available_project_modules).to include(:project_module, :mixed_module, :dependent_module) }
    it { expect(available_project_modules).not_to include(:global_module) }

    context 'when a module specifies :if' do
      before do
        described_class.map do |map|
          map.project_module :dynamic_module, if: if_proc do |mod|
            mod.permission :perm_d1, { dont: :care }, permissible_on: :project
          end
        end
      end

      context 'with if: true' do
        let(:if_proc) { ->(*) { true } }

        it 'is considered available' do
          expect(available_project_modules).to include(:dynamic_module)
        end
      end

      context 'with if: false' do
        let(:if_proc) { ->(*) { false } }

        it 'is not considered available anymore' do
          expect(available_project_modules).not_to include(:dynamic_module)
        end
      end

      context 'with if: dynamically changing' do
        let(:if_proc) { ->(*) { if_state[:available] } }
        let(:if_state) { { available: true } }

        it 'reevaluates module availability each time', :aggregate_failures do
          if_state[:available] = true
          expect(described_class.available_project_modules).to include(:dynamic_module)

          if_state[:available] = false
          expect(described_class.available_project_modules).not_to include(:dynamic_module)
        end
      end
    end
  end

  describe '.contract_actions_map' do
    include_context 'with blank access control state'

    before do
      setup_permissions
    end

    subject(:contract_actions_map) do
      described_class.contract_actions_map
    end

    it 'contains all contract actions grouped by the permission name' do
      expect(contract_actions_map)
        .to eql(mixed_module_global_permission_with_contract_actions: {
                  actions: { baz: [:destroy] },
                  global: true,
                  module_name: :mixed_module,
                  grant_to_admin: true,
                  public: false
                },
                no_module_project_permission_with_contract_actions: {
                  actions: { foo: :create },
                  global: false,
                  module_name: nil,
                  grant_to_admin: true,
                  public: false
                },
                project_module_project_permission_with_contract_actions: {
                  actions: { bar: %i[create read] },
                  global: false,
                  module_name: :project_module,
                  grant_to_admin: true,
                  public: true
                })
    end
  end

  describe '.grant_to_admin?' do
    include_context 'with blank access control state'

    before do
      setup_permissions
    end

    context 'without specifying whether the permission is granted to admins' do
      it 'is granted' do
        expect(described_class)
          .to be_grant_to_admin(:no_module_project_permission_with_contract_actions)
      end
    end

    context 'for an explicitly granted permission' do
      it 'is granted' do
        expect(described_class)
          .to be_grant_to_admin(:mixed_module_project_permission_granted_to_admin)
      end
    end

    context 'for an explicitly non-granted permission' do
      it 'is not granted' do
        expect(described_class)
          .not_to be_grant_to_admin(:dependent_module_project_permission_not_granted_to_admin)
      end
    end

    context 'for a non existing permission' do
      it 'is granted' do
        expect(described_class)
          .to be_grant_to_admin(:not_existing)
      end
    end
  end
end
