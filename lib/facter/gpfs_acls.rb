is_gpfs = false
File.read('/proc/filesystems').each_line { |line|
  if line =~ /gpfs/
    is_gpfs = true
  end
}

if is_gpfs == true
   Facter.add("gpfs_acls") do
     setcode do
       filesystems = Hash.new
       out = Facter::Core::Execution.exec("/usr/lpp/mmfs/bin/mmlsfs all")
       if out
         acls = ''
         filesystem = ''
         out.each_line { |line|
           if line =~ /-k[ ]*([a-z0-9]*)/
             acls= $1
           end
           if line =~ /-T[ ]*([a-z0-9\/]*)/
             filesystem = $1
           end
           if line != '' and filesystem != ''
             filesystems[filesystem] = acls
             filesystem = ''
             acls = ''
           end
         }
       end
       filesystems
     end
   end
end
