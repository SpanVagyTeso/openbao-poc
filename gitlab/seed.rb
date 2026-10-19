# Run with gitlab-rails runner after every reconfigure.
# Seeds what the API can't: the root token used by OpenTofu, and demo users with a weak password.

# --- Root personal access token ---
# sudo lets OpenTofu act as the demo users, e.g. to commit as them
TOKEN_SCOPES = %w[api sudo].freeze
token_value = File.read('/secrets/root-token').strip

existing = PersonalAccessToken.find_by_token(token_value)
if existing&.active? && existing.scopes.map(&:to_s).sort == TOKEN_SCOPES.sort
  puts 'Root personal access token already exists'
else
  # Expired, revoked or outdated scopes: replace it with a fresh token that has the same value
  existing&.destroy!

  token = User.find_by_username!('root').personal_access_tokens.build(
    name: 'opentofu',
    scopes: TOKEN_SCOPES,
    expires_at: 365.days.from_now
  )
  token.set_token(token_value)
  token.save!
  puts 'Root personal access token created'
end

# --- Demo users ---
# OpenBao signs SSH keys for fodor.kristof and other-user, each only for their own login on ssh-target;
# unknown shows that everyone else is rejected
# GitLab rejects passwords shorter than 8 characters at login, even if they were stored
DEMO_PASSWORD = 'almaalma'
DEMO_USERS = [
  { username: 'fodor.kristof', name: 'Fodor Kristóf', email: 'fodor.kristof@microsec.hu' },
  { username: 'other-user', name: 'Other User', email: 'other-user@microsec.hu' },
  { username: 'unknown', name: 'Unknown User', email: 'unknown@microsec.hu' }
].freeze

admin = User.find_by_username!('root')

DEMO_USERS.each do |attrs|
  user = User.find_by_username(attrs[:username])
  unless user
    # Create with a policy-compliant password first, so namespace and confirmation are handled normally
    result = Users::CreateService.new(admin, attrs.merge(
      password: SecureRandom.alphanumeric(32),
      skip_confirmation: true,
      organization_id: Organizations::Organization.first.id
    )).execute
    raise "Cannot create #{attrs[:username]}: #{result.message}" unless result.success?

    user = result.payload[:user]
    puts "User #{attrs[:username]} created"
  end

  next if user.valid_password?(DEMO_PASSWORD)

  # Skip validation, which would reject the password as too weak
  user.password = DEMO_PASSWORD
  user.password_confirmation = DEMO_PASSWORD
  user.password_automatically_set = false
  user.password_expires_at = nil
  user.save!(validate: false)
  raise "Password of #{attrs[:username]} was not applied" unless user.reload.valid_password?(DEMO_PASSWORD)

  puts "Password of #{attrs[:username]} set"
end
