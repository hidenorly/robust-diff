#!/usr/bin/ruby

# Copyright 2023 hidenorly
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'optparse'
require_relative 'ExecUtil'
require_relative 'FileUtil'
require_relative 'TaskManager'
require 'fileutils'
require 'shellwords'

class ExecDiff < TaskAsync
	def initialize( srcFile, targetFile, outputFile, verbose=false )
		super("ExecDiff::#{srcFile}:#{targetFile}")
		@srcFile=srcFile
		@targetFile=targetFile
		@outputFile=outputFile
		@verbose = verbose
	end

	def execute
		exec_cmd = "diff -u -E -b -w -B -I -N #{Shellwords.escape(@srcFile)} #{Shellwords.escape(@targetFile)}"
		puts exec_cmd if @verbose

		results = ExecUtil.getExecResultEachLine(exec_cmd, FileUtil.getDirectoryFromPath(@outputFile), false)
		FileUtil.writeFile(@outputFile, results)

		_doneTask()
	end
end

class FileUtil
	def self.getRobustCommonPath(srcBasePath, srcPath, dstBasePath, dstFiles)
		relativeSrcPath = srcPath.slice(srcBasePath.length+1, srcPath.length)
		result = "#{dstBasePath}/#{relativeSrcPath}"
		if !FileTest.exist?(result) then
			filename = FileUtil.getFilenameFromPath(relativeSrcPath)
			dstFiles.each do |aDstFile|
				if aDstFile.include?(filename) then
					result = aDstFile
					break
				end
			end
		end
		return result
	end
end

class DiffUtil
	def self.getDiffTargetAndMissedAndOutputFiles(sourceBasePath, sourceFiles, targetBasePath, targetFiles, outputPathBase, diffTargetFiles={}, missedFiles={}, isRobustMissingFileSearch=false, isUseSourceNameForOutput)
		sourceFiles.each do |aSrcFile|
			targetFilename = FileUtil.getRobustCommonPath(sourceBasePath, aSrcFile, targetBasePath, targetFiles)
			theTargetFilename = FileUtil.getFilenameFromPath(targetFilename)
			relativeSrcPath = isUseSourceNameForOutput ? aSrcFile.slice(sourceBasePath.length+1, aSrcFile.length) : targetFilename.slice(targetBasePath.length+1, targetFilename.length)
			outputFilename = "#{outputPathBase}/#{relativeSrcPath.gsub("/", "-")}"
			if FileTest.exist?(aSrcFile) && FileTest.exist?(targetFilename) then
				diffTargetFiles[theTargetFilename] = [aSrcFile, targetFilename, outputFilename]
			else
				if !missedFiles.has_key?(theTargetFilename) || !isRobustMissingFileSearch then
					if !FileTest.exist?(targetFilename) then
						missedFiles[theTargetFilename] = targetFilename
					end
				end
			end
		end
		return diffTargetFiles, missedFiles
	end
end



#---- main --------------------------
options = {
	:srcDir => ".",
	:dstDir => nil,
	:output => ".",
	:useSourceNameForOutput => false,
	:filter => nil,
	:robustMissingFileSearch => true,
	:outputNotFoundFiles => false,
	:verbose => false,
	:numOfThreads => TaskManagerAsync.getNumberOfProcessor()
}

opt_parser = OptionParser.new do |opts|
	opts.banner = "Usage: -s sourceDir -t destDir -o outputDir"

	opts.on("-s", "--srcDir=", "Specify srcDir (old)") do |srcDir|
		options[:srcDir] = srcDir
	end

	opts.on("-t", "--dstDir=", "Specify dstDir (new)") do |dstDir|
		options[:dstDir] = dstDir
	end

	opts.on("-f", "--filter=", "Specify filename filter regexp") do |filter|
		options[:filter] = filter
	end

	opts.on("-o", "--output=", "Specify output path") do |output|
		options[:output] = output
	end

	opts.on("-u", "--useSourceNameForOutput", "Specify if you want to output with the source file basis") do
		options[:useSourceNameForOutput] = true
	end

	opts.on("-m", "--outputNotFoundFiles", "Specify if you want to output not found files") do
		options[:outputNotFoundFiles] = true
	end

	opts.on("-j", "--numOfThreads=", "Specify number of threads (default:#{options[:numOfThreads]})") do |numOfThreads|
		options[:numOfThreads] = numOfThreads
	end

	opts.on("-v", "--verbose", "Enable verbose") do
		options[:verbose] = true
	end
end.parse!

options[:srcDir] = File.expand_path(options[:srcDir]) if options[:srcDir]
options[:dstDir] = File.expand_path(options[:dstDir]) if options[:dstDir]

if !Dir.exist?(options[:srcDir]) || !Dir.exist?(options[:dstDir]) then
	puts "-s and -t should be specified"
	exit(-1)
end

taskMan = ThreadPool.new( options[:numOfThreads].to_i )

# ensure output path
FileUtil.ensureDirectory( options[:output] )

sourceFiles = FileUtil.getRegExpFilteredFilesMT2(options[:srcDir], nil)
sourceFiles = sourceFiles.select{ |aFilename| aFilename.match(options[:filter]) } if options[:filter]
targetFiles = FileUtil.getRegExpFilteredFilesMT2(options[:dstDir], nil)
targetFiles = targetFiles.select{ |aFilename| aFilename.match(options[:filter]) } if options[:filter]

diffTargetFiles = {}
missedFiles = {}
diffTargetFiles, missedFiles = DiffUtil.getDiffTargetAndMissedAndOutputFiles( options[:srcDir], sourceFiles, options[:dstDir], targetFiles, options[:output], diffTargetFiles, missedFiles, false, options[:useSourceNameForOutput])
diffTargetFiles, missedFiles = DiffUtil.getDiffTargetAndMissedAndOutputFiles( options[:dstDir], targetFiles, options[:srcDir], sourceFiles, options[:output], diffTargetFiles, missedFiles, options[:robustMissingFileSearch], !options[:useSourceNameForOutput] )

if options[:outputNotFoundFiles] || options[:verbose] then
	missedFiles.each do |aMissedFilename, aMissedFilePath|
		puts "#{aMissedFilePath} is not found"
	end
end

diffTargetFiles.each do |theFilename, targetOutputFiles|
	aSrcFile = targetOutputFiles[0]
	targetFilename = targetOutputFiles[1]
	outputFilename = targetOutputFiles[2]
	puts "diff #{aSrcFile} #{targetFilename} > #{outputFilename}" if options[:verbose]
	taskMan.addTask( ExecDiff.new( aSrcFile, targetFilename, outputFilename, options[:verbose]) )
end

taskMan.executeAll()
taskMan.finalize()
