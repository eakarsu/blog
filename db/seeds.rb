if ENV["BOOTSTRAP_ADMIN_EMAIL"].present?
  email = ENV.fetch("BOOTSTRAP_ADMIN_EMAIL").downcase.strip
  username = ENV.fetch("BOOTSTRAP_ADMIN_USERNAME")
  password = ENV.fetch("BOOTSTRAP_ADMIN_PASSWORD")
  raise "BOOTSTRAP_ADMIN_PASSWORD must be 16-72 characters" unless password.length.between?(16, 72)

  user = User.find_or_initialize_by(email: email)
  user.assign_attributes(username: username, password: password, role: "administrator", active: true)
  user.save!
  puts "Administrator account provisioned for #{email}; remove bootstrap variables now."
else
  puts "No bootstrap administrator requested. Set explicit BOOTSTRAP_ADMIN_* variables for a one-time provisioning run."
end
