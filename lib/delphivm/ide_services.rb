require 'fiddle'
require 'fiddle/import'
require 'delphivm/tool'
require 'delphivm/win_services'

class Delphivm
	IDEInfos = Delphivm.configuration.known_ides || {}

 	class IDEServices
		attr :idever
		attr :workdir
		attr :build_tool

		def self.idelist(kind = :installed)
			ide_filter_valid?(kind) ? send("ides_in_#{kind}") : []
		end
		
		def self.ide_filter_valid?(kind)
			%W(config installed prj).include?(kind.to_s)
		end

		def self.default_ide
		 	self.ides_in_prj.last.to_s
		end
			
		def self.ides_in_config
		 	IDEInfos.to_h.keys.sort
		end

		def self.ides_in_installed
			ides_filter(ides_in_config, :installed)
		end

		def self.ides_in_prj
			ides_filter(ides_in_config, :prj)
		end

		def self.ides_filter(ides, kind)
			ide_filter_valid?(kind) ? ides.select {|ide| send("ide_in_#{kind}?", ide)} : []
		end

		def self.ide_in_config?(ide)
			ides_in_config.include?(ide)
		end

		def self.ide_in_installed?(ide)
			(Win32::Registry::HKEY_CURRENT_USER.open(IDEInfos[ide][:regkey]) {|reg| reg} rescue false)
		end
		
		def self.ide_in_prj?(ide)
		 	!ROOT.glob("{src}/#{ide.to_s}*/").empty?
		end

		def self.platforms_in_prj(ide)
			(ROOT + 'out' + ide + '**/lib/').glob.map{|p| p.parent.parent.basename.to_s}
		end

		def self.use(ide_tag)
		 	bin_paths = ide_paths.map{ |p| p + 'bin' }
		 	bpl_paths = []
		 	paths_to_remove = [""] + bin_paths + bpl_paths
		 	paths_to_remove =  paths_to_remove.map{|p| p.upcase}
	         
		 	path = Win32::Registry::HKEY_CURRENT_USER.open('Environment'){|r| r['PATH']}
		 	path = path.split(';')
		 	path.reject! { |p|  paths_to_remove.include?(p.upcase)  }

		 	new_bin_path = ide_paths(ide_tag.upcase).map{ |p| p + 'bin' }.first
		  	path.unshift new_bin_path

		 	new_bpl_path = ide_paths(ide_tag.upcase).map{ |p| p + 'bpl' }.first
		  	path.unshift new_bpl_path

		  	path = path.join(';')
		  	WinServices.winpath = path
		  	return path
		end
			
		def initialize(idever, workdir=ROOT)
			@idever = idever.to_s.upcase
			@workdir = workdir
			@reg = Win32::Registry::HKEY_CURRENT_USER     
			@build_tool = supports_msbuild? ? MSBuild.new(self) : IDETool.new(self)
		end
		 
		def [](key)
		  @reg.open(IDEInfos[idever][:regkey]) {|r| r[key] }
		end
		  
		def set_env
		 	ENV["PATH"] = '$(BDSCOMMONDIR)\bpl;' + ENV["PATH"]
		 	ENV["PATH"] = self['RootDir'] + 'bin;' + ENV["PATH"]
		 	ENV["PATH"] = vendor_bin_paths.join(';') + ';' + ENV["PATH"]

		 	ENV["BDSPROJECTGROUPDIR"] = workdir.win
		 	ENV["IDEVERSION"] = idever.to_s
		end

		def prj_slug
		 	workdir.basename.to_s.upcase
		end
		
		def prj_regkey
			"DelphiVM\\#{prj_slug}"
		end

		def pkg_regkey
			regkey = Pathname(IDEInfos[idever][:regkey])
			"HKCU\\#{regkey.parent.parent}\\#{prj_regkey}\\#{regkey.basename}\\Known Packages"
		end

		def vendor_bin_paths
		    Pathname.glob(PATH_TO_VENDOR_IMPORTS + idever + '**' + 'bin').map{|p| p.win}
		end

		def supports_msbuild?
			ide_number = idever[1..-1].to_i
			ide_number > 140
		end
		
		def group_file_ext
			supports_msbuild? ? 'groupproj' : 'bdsgroup'
		end

		def get_main_group_file
			Pathname.glob(workdir + "src/#{idever}**/#{prj_slug}App.#{group_file_ext}").first || 
			Pathname.glob(workdir + "src/#{idever}**/*.#{group_file_ext}").first
		end

		def start(main_group_file=nil)
			set_env
			main_group_file ||= get_main_group_file
			#bds_args = IDETool.new(self).args(file: main_group_file.win).cmdln_args
			bds_args = IDETool.new(self).cmdln_args
			Process.detach(spawn "#{self['App']}", bds_args)
			say "[#{idever}] ", :green
			say "started bds #{bds_args}"
		end
		
		def call_build_tool(target, config)
		 	set_env
		 	WinServices.winshell(out_filter: ->(line){line =~/\b(warning|hint|error)\b/i}) do |i|
		 	# WINServices..winshell do |i|
			Pathname.glob(workdir + "{src,samples,test}/#{idever}**/*.#{group_file_ext}") do |f|
				f_to_show = f.relative_path_from(workdir)
				build_tool.args(config: config, target: target, file: f)
				say "[#{idever}] ", :green
				say "#{target.upcase}: #{f_to_show}"
				say("[#{build_tool.title}] ", :green)
				say(build_tool.cmdln_args)
				say
				build_tool.call(i)
			end  
	  	end    
	end
	
  private
	
	def self.say(*args)
		Delphivm.shell.say(*args)
	end
		
	def say(*args)
		self.class.say(*args)
	end

	def self.ide_paths(idetag=nil)
		result = []
		IDEInfos.each do |key, info|
			Win32::Registry::HKEY_CURRENT_USER.open(info[:regkey]) { |r| 	
				result << r['RootDir'] if (idetag.nil? || idetag.to_s == key)
			} rescue true
		end
		result
	end
	
  end
end
