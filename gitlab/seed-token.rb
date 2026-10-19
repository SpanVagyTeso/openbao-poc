# Run with gitlab-rails runner after every reconfigure.
# Registers the pre-generated root token as a personal access token, so OpenTofu can use the API.
token_value = File.read('/secrets/root-token').strip

existing = PersonalAccessToken.find_by_token(token_value)
if existing&.active?
  puts 'Root personal access token already exists'
else
  # Expired or revoked: replace it with a fresh token that has the same value
  existing&.destroy!

  token = User.find_by_username!('root').personal_access_tokens.build(
    name: 'opentofu',
    scopes: %w[api],
    expires_at: 365.days.from_now
  )
  token.set_token(token_value)
  token.save!
  puts 'Root personal access token created'
end
