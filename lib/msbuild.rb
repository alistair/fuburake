# vim: tabstop=4:softtabstop=4:shiftwidth=4:noexpandtab
module FubuRake
	class MSBuild
		def self.create_task(tasks, options)
			if tasks.compile == nil 
				return nil
			end
	  
			compileTask = Rake::Task.define_task :compile do
				MSBuildRunner.compile options.merge(tasks.compile)
			end

			compileTask.add_description "Compiles the solution #{tasks.compile[:solutionfile]}"
	  
			openTask = Rake::Task.define_task :sln do
				Platform.open("#{tasks.compile[:solutionfile]}")
			end
			openTask.add_description "Open solution #{tasks.compile[:solutionfile]}"

			tasks.compile_targets.each do |m|
				create_mode_task m, tasks, options
			end
			
			return compileTask
		end
		
		def self.create_mode_task(mode, tasks, options)
			compile_options = options.merge(tasks.compile)
			compile_options[:compilemode] = mode
			
			task = Rake::Task.define_task "compile:#{mode.downcase}" do
				MSBuildRunner.compile compile_options
			end
			
			task.enhance(tasks.precompile)
			task.add_description "Compiles the solution in #{mode} mode"
		end
		
		
	end
  
	class CompileTarget
		def initialize(name, solution)
			@name = name
			@solution = solution
		end
	
		def create(options)
			compileTask = Rake::Task.define_task @name do
				MSBuildRunner.compile options.merge({:solutionfile => @solution})
			end
		
			compileTask.add_description "Compiles #{@solution}"
		end
	end
end


class MSBuildRunner
	def self.compile(attributes)
		compileTarget = attributes.fetch(:compilemode, 'Debug')
		solutionFile = attributes[:solutionfile]

		attributes[:projFile] = solutionFile
		attributes[:properties] ||= []
		attributes[:properties] << "Configuration=#{compileTarget}"
		attributes[:extraSwitches] = ["v:m", "t:rebuild", "nr:False"]
		attributes[:extraSwitches] << "maxcpucount:2" unless Platform.is_nix

		self.runProjFile(attributes);
	end

	def self.runProjFile(attributes)
		version = attributes.fetch(:clrversion, 'v4.0.30319')
		compileTarget = attributes.fetch(:compilemode, 'debug')
		projFile = attributes[:projFile]

		if Platform.is_nix
			msbuildFile = `which xbuild`.chop
			attributes[:properties] << "TargetFrameworkProfile="""""
		else
			frameworkDir = File.join(ENV['windir'].dup, 'Microsoft.NET', 'Framework', version)
			msbuildFile = File.join(frameworkDir, 'msbuild.exe')
		end

		properties = attributes.fetch(:properties, [])

		switchesValue = ""

		properties.each do |prop|
			switchesValue += " /property:#{prop}"
		end

		extraSwitches = attributes.fetch(:extraSwitches, [])

		extraSwitches.each do |switch|
			switchesValue += " /#{switch}"
		end

		targets = attributes.fetch(:targets, [])
		targetsValue = ""
		targets.each do |target|
			targetsValue += " /t:#{target}"
		end
		
		sh "#{msbuildFile} #{projFile} #{targetsValue} #{switchesValue}"
	end
end
