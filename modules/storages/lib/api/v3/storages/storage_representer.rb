#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2022 the OpenProject GmbH
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

# Reference: Representable https://trailblazer.to/2.1/docs/representable.html
#   "Representable maps Ruby objects to documents and back"
# Reference: Roar is a thin layer on top of Representable https://github.com/trailblazer/roar
# Reference: Roar-Rails integration: https://github.com/apotonick/roar-rails
module API
  module V3
    module Storages
      URN_TYPE_NEXTCLOUD = "#{::API::V3::URN_PREFIX}storages:Nextcloud".freeze
      URN_CONNECTION_CONNECTED = "#{::API::V3::URN_PREFIX}storages:authorization:Connected".freeze
      URN_CONNECTION_AUTH_FAILED = "#{::API::V3::URN_PREFIX}storages:authorization:FailedAuthentication".freeze
      URN_CONNECTION_ERROR = "#{::API::V3::URN_PREFIX}storages:authorization:Error".freeze

      class StorageRepresenter < ::API::Decorators::Single
        # LinkedResource module defines helper methods to describe attributes
        include API::Decorators::LinkedResource
        include API::Decorators::DateProperty

        property :id

        property :name

        date_time_property :created_at

        date_time_property :updated_at

        # A link back to the specific object ("represented")
        self_link

        link :type do
          {
            href: URN_TYPE_NEXTCLOUD,
            title: 'Nextcloud'
          }
        end

        link :origin do
          {
            href: represented.host
          }
        end

        link :authorizationState do
          oauth_client = represented.oauth_client
          connection_manager = ::OAuthClients::ConnectionManager.new(user: User.current, oauth_client:)
          status_urn = urn_authorization_state(connection_manager.authorization_state)
          {
            href: status_urn,
            title: urn_authorization_state_title(status_urn)
          }
        end

        def _type
          'Storage'
        end

        private

        # Check the ConnectionManager for the OAuth2 status
        def urn_authorization_state(authorization_state)
          case authorization_state
          when :error
            URN_CONNECTION_ERROR
          when :connected
            URN_CONNECTION_CONNECTED
          when :failed_authentication
            URN_CONNECTION_AUTH_FAILED
          else
            # This should never happen
            raise StandardError
          end
        end

        # Provide a human readable title for the connection status
        def urn_authorization_state_title(token_status)
          case token_status
          when URN_CONNECTION_CONNECTED
            I18n.t(:"urn_authorization_state")
          when URN_CONNECTION_AUTH_FAILED
            I18n.t(:"urn_authorization_state")
          else
            # Mainly covers URN_CONNECTION_ERROR
            I18n.t(:"urn_authorization_state")
          end
        end
      end
    end
  end
end
