#!/usr/bin/env python3
# coding: utf-8
#   Copyright 2023 hidenorly
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

import argparse
import difflib

class FileUtil:
    @staticmethod
    def readFile(path):
        result = []
        try:
            with open(path, 'r') as file:
                result = file.readlines()
        except:
            pass
        return result

class DiffUtil:
    @staticmethod
    def removeComments(lines, isStrip, isIgnoreComment):
        results = []

        if isIgnoreComment:
            isMultiLineComment = False
            for aLine in lines:
                if isStrip:
                    aLine = aLine.strip()
                aLine = DiffUtil.removeSingleLineComment(aLine)
                aLine, isMultiLineComment = DiffUtil.removeMultiLineComment(aLine, isMultiLineComment)
                if isStrip:
                    aLine = aLine.strip()
                if aLine:
                    results.append(aLine)
        else:
            results = lines

        return results

    @staticmethod
    def removeSingleLineComment(line):
        index = line.find('//')
        if index >= 0:
            line = line[:index]
        return line

    @staticmethod
    def removeMultiLineComment(line, isMultiLineComment):
        indexStart = line.find('/*')
        if indexStart >= 0:
            isMultiLineComment = True
            line = line[:indexStart]

        indexEnd = line.find('*/')
        if indexEnd >= 0:
            isMultiLineComment = False
            line = line[indexEnd+2:]

        if isMultiLineComment and indexStart<0 and indexEnd<0:
            line = ""

        return line, isMultiLineComment

    @staticmethod
    def compareFiles(files, isStrip, isIgnoreComment):
        results = []

        if len(files) == 2:
            fileBodies = []
            for aFile in files:
                fileBodies.append( DiffUtil.removeComments( FileUtil.readFile(aFile), isStrip, isIgnoreComment ) )

            differ = difflib.Differ()
            diff = list(differ.compare(fileBodies[0], fileBodies[1]))

            for aLine in diff:
                if aLine.startswith(' '):
                    continue
                results.append(aLine)

        return results

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Parse command line options.')
    parser.add_argument('args', nargs='*', help='file1 file2')
    parser.add_argument('-s', '--strip', default=False, action='store_true', help='Ignore blank, etc.')
    parser.add_argument('-c', '--ignoreComment', default=False, action='store_true', help='Ignore comments //, /* */')

    args = parser.parse_args()


    diffLines = DiffUtil.compareFiles(args.args, args.strip, args.ignoreComment)
    for aLine in diffLines:
        print(aLine)
