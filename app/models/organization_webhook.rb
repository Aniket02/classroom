# frozen_string_literal: true

class OrganizationWebhook < ApplicationRecord
  class NoValidTokenError < StandardError; end

  has_many :organizations
  has_many :users, through: :organizations

  validates :github_id, uniqueness: true, allow_nil: true

  validates :github_organization_id, presence:   true
  validates :github_organization_id, uniqueness: true

  # External: Finds a User token in the same GitHub organization
  # that has the `admin:org_hook` scope. Used for creating webhooks.
  #
  # organization - the organization to search for users in.
  #
  # Example:
  #
  #   admin_org_hook_scoped_github_client
  #   # => {token_string}
  #
  # Returns a User's token or raises a NoValidTokenError if one could not be found.
  #
  # Warning: This could potentially take very long for organizations
  # of a large size, so invoke cautiously.
  # Pass an organization argument to shrink the search scope for newly created classrooms.
  def admin_org_hook_scoped_github_client(organization: nil)
    token = if Rails.env.test?
              users.first&.token
            else
              users_with_admin_org_hook_scope(organization).sample&.token
            end
    raise NoValidTokenError, "No valid token with the `admin:org` hook scope." if token.nil?
    Octokit::Client.new(access_token: token)
  end

  private

  # Internal: Finds Users in the same GitHub organization
  # that have the `admin:org_hook` scope.
  #
  # organization - the organization to search for users in.
  #
  # Example:
  #
  #   users_with_admin_org_hook_scope
  #   # => [#<User:0x007fd7f0320a30
  #      id: 1,
  #      uid: 564113,
  #      token: "8675309",
  #      created_at: Sun, 20 Nov 2016 16:29:43 UTC +00:00,
  #      updated_at: Tue, 22 Nov 2016 03:46:10 UTC +00:00,
  #      site_admin: true,
  #      last_active_at: Fri, 25 Nov 2016 03:39:54 UTC +00:00>]
  #
  # Returns a list of Users with the `admin:org` scope token
  # or an empty list if none could be found.
  #
  # Warning: This could potentially take very long for organizations
  # of a large size, so invoke cautiously.
  # Pass an organization argument to shrink the search scope for newly created classrooms.
  def users_with_admin_org_hook_scope(organization = nil)
    return @users_with_scope if defined?(@users_with_scope)

    @users_with_scope = []

    search_scope = organization.present? ? organization : self

    search_scope.users.find_in_batches(batch_size: 100) do |users|
      users.each do |user|
        next unless user.github_client_scopes.include?("admin:org_hook")
        @users_with_scope << user
      end
    end

    @users_with_scope
  end
end
