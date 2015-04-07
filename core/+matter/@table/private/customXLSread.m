 function [numOut, textOut, rawOut] = customXLSread(sFile, sWorksheetname)
            % this is a customised xlsread function
            % no unnecessary functionality like xml import function and lots of queries removed
            % it is used in MatterImport
            %
            % customXlsread returns
            %  numOut: numeric data from worksheet
            %  textOut: string data from worksheet
            %  rawOut: all data from worksheet
            %
            % inputs:
            % sFile: filename of excelfile
            % sWorksheetname: name of worksheet for import
            
            % no arguments handed over, abort function
            if nargin < 2 || isempty(sFile) || isempty(sWorksheetname)
                numOut = [];
                textOut = [];
                rawOut = [];
                return
            end
            
            % used activeXserver is only available at windows
            basicMode = ~ispc;
            
            % Try to reuse an existing COM server instance if possible
            try
                Excel = actxGetRunningServer('excel.application');
                % no crash so probably succeeded to connect to a running server
            catch
                % Never mind - try to continue normally to start the COM server and connect to it
                try
                    Excel = actxserver('excel.application');
                catch
                    % no activeXserver available or excel not installed, use basic mode of xlsread
                    basicMode = true;
                end
            end
            
            % use xlsread in basic mode
            if basicMode
                [numOut, textOut, rawOut] = xlsread(sFile, sWorksheetname, '', 'basic');
                return
            end
            
            % try to get full path of file
            try
                sFile = validpath(sFile);
            catch exception
                error(message('MATLAB:xlsread:FileNotFound', sFile, exception.message));
            end
            
            readOnly = true;
            Excel.DisplayAlerts = 0;
            
            % Associate event handler for COM object event at run time
            registerevent(Excel,{'WorkbookActivate', @WorkbookActivateHandler});
            % open worksheet in readonly mode
            Excel.workbooks.Open(sFile, 0, readOnly);
            
            % wait for response from activeXserver to open worksheet
            for i = 1:500
                try
                    workbook.FileFormat;
                    break;
                catch exception %#ok<NASGU>
                    pause(0.01);
                end
            end
            
            WorkSheets = workbook.Worksheets;
            
            % Get name of specified worksheet from workbook
            try
                TargetSheet = get(WorkSheets,'item',sWorksheetname);
            catch  %#ok<CTCH>
                error(message('MATLAB:xlsread:WorksheetNotFound', sWorksheetname));
            end
            
            %Activate silently fails if the sheet is hidden
            set(TargetSheet, 'Visible','xlSheetVisible');
            % activate worksheet
            Activate(TargetSheet);
            
            % get range of worksheet
            DataRange = workbook.ActiveSheet.UsedRange;
            
            % get data from worksheet
            rawOut = DataRange.Value;
            if ~iscell(rawOut)
                rawOut = {rawOut};
            end
            
            % get numeric and text data splited from worksheetdata
            [numOut, textOut] = xlsreadSplitNumericAndText(rawOut);
            
            % nested functions
            % used from private folder iofun on matlabpath
            
            % -------------------------------------------------------------------------
            % for workbook activation
            function WorkbookActivateHandler(varargin)
                workbook = varargin{3};
            end
            
            % -------------------------------------------------------------------------
            % for Split Numeric And Text
            function [numericData, textData] = xlsreadSplitNumericAndText(data)
                % xlsreadSplitNumericAndText parses raw data into numeric and text arrays.
                %   [numericData, textData] = xlsreadSplitNumericAndText(DATA) takes cell
                %   array DATA from spreadsheet and returns a double array numericData and
                %   a cell string array textData.
                %
                %   See also XLSREAD, XLSWRITE, XLSFINFO.
                
                %   Copyright 1984-2012 The MathWorks, Inc.
                
                
                % ensure data is in cell array
                if ischar(data)
                    data = cellstr(data);
                elseif isnumeric(data) || islogical(data)
                    data = num2cell(data);
                end
                
                % Check if raw data is empty
                if isempty(data)
                    % Abort when all data cells are empty.
                    textData = {};
                    numericData = [];
                    return
                end
                
                % Initialize textData as an empty cellstr of the right size.
                textData = cell(size(data));
                textData(:) = {''};
                
                % Find non-numeric entries in data cell array
                isTextMask = cellfun('isclass',data,'char');
                
                % Place text cells in text array
                if any(isTextMask(:))
                    textData(isTextMask) = data(isTextMask);
                else
                    textData = {};
                end
                % Excel returns COM errors when it has a #N/A field.
                textData = strrep(textData,'ActiveX VT_ERROR: ','#N/A');
                
                % Trim the leading and trailing empties from textData
                emptyTextMask = cellfun('isempty', textData);
                textData = filterDataUsingMask(textData, emptyTextMask);
                
                % place NaN in empty numeric cells
                if any(isTextMask(:))
                    data(isTextMask)={NaN};
                end
                
                % Find non-numeric entries in data cell array
                isLogicalMask = cellfun('islogical',data);
                
                % Convert cell array to numeric array through concatenating columns then
                % rows.
                cols = size(data,2);
                tempDataColumnCell = cell(1,cols);
                % Concatenate each column first
                for n = 1:cols
                    tempDataColumnCell{n} = cat(1, data{:,n});
                end
                % Now concatenate the single column of cells into a numeric array.
                numericData = cat(2, tempDataColumnCell{:});
                
                % Trim all-NaN leading and trailing rows and columns from numeric array
                isNaNMask = isnan(numericData);
                if all(isNaNMask(:))
                    numericData = [];
                else
                    [numericData, isNaNMask] = filterDataUsingMask(numericData, isNaNMask);
                end
                
                % Restore logical type if all values were logical.
                if any(isLogicalMask(:)) && ~any(isNaNMask(:))
                    numericData = logical(numericData);
                end
                
                % Ensure numericArray is 0x0 empty.
                if isempty(numericData)
                    numericData = [];
                end
            end
            
            % -------------------------------------------------------------------------
            function  [row, col] = getCorner(mask, firstlast)
                isLast = strcmp(firstlast,'last');
                
                % Find first (or last) row that is not all true in the mask.
                row = find(~all(mask,2), 1, firstlast);
                if isempty(row)
                    row = emptyCase(isLast, size(mask,1));
                end
                
                % Find first (or last) column that is not all true in the mask.
                col = find(~all(mask,1), 1, firstlast);
                % Find returns empty if there are no rows/columns that contain a false value.
                if isempty(col)
                    col = emptyCase(isLast, size(mask,2));
                end
            end
            
            % -------------------------------------------------------------------------
            function [data, mask] = filterDataUsingMask(data, mask)
                [rowStart, colStart] = getCorner(mask, 'first');
                [rowEnd, colEnd] = getCorner(mask, 'last');
                data = data(rowStart:rowEnd, colStart:colEnd);
                mask = mask(rowStart:rowEnd, colStart:colEnd);
            end
            
            % -------------------------------------------------------------------------
            function dim = emptyCase(isLast, dimSize)
                if isLast
                    dim = dimSize;
                else
                    dim = 1;
                end
            end
            
            % -------------------------------------------------------------------------
            % for generation of full filepath
            function filenameOut = validpath(filename)
                % VALIDPATH builds a full path from a partial path specification
                %   FILENAME = VALIDPATH(FILENAME) returns a string vector containing full
                %   path to a file. FILENAME is string vector containing a partial path
                %   ending in a file or directory name. May contain ..\  or ../ or \\. The
                %   current directory (pwd) is prepended to create a full path if
                %   necessary. On UNIX, when the path starts with a tilde, '~', then the
                %   current directory is not prepended.
                %
                %   See also XLSREAD, XLSWRITE, XLSFINFO.
                
                %   Copyright 1984-2012 The MathWorks, Inc.
                
                %First check for wild cards, since that is not supported.
                if strfind(filename, '*') > 0
                    error(message('MATLAB:xlsread:Wildcard', filename));
                end
                
                % break partial path in to file path parts.
                [Directory, file, ext] = fileparts(filename);
                
                if ~isempty(ext)
                    filenameOut = getFullName(filename);
                else
                    extIn = matlab.io.internal.xlsreadSupportedExtensions;
                    for ii = 1:length(extIn)
                        try                                                                %#ok<TRYNC>
                            filenameOut = getFullName(fullfile(Directory, [file, extIn{i}]));
                            return;
                        end
                    end
                    error(message('MATLAB:xlsread:FileDoesNotExist', filename));
                end
            end
            
            % -------------------------------------------------------------------------
            function absolutepath=abspath(partialpath)
                
                % parse partial path into path parts
                [pathname, filename, ext] = fileparts(partialpath);
                % no path qualification is present in partial path; assume parent is pwd, except
                % when path string starts with '~' or is identical to '~'.
                if isempty(pathname) && strncmp('~', partialpath, 1)
                    Directory = pwd;
                elseif isempty(regexp(partialpath,'(.:|\\\\)', 'once')) && ...
                        ~strncmp('/', partialpath, 1) && ...
                        ~strncmp('~', partialpath, 1);
                    % path did not start with any of drive name, UNC path or '~'.
                    Directory = [pwd,filesep,pathname];
                else
                    % path content present in partial path; assume relative to current directory,
                    % or absolute.
                    Directory = pathname;
                end
                
                % construct absolute filename
                absolutepath = fullfile(Directory,[filename,ext]);
            end
            
            % -------------------------------------------------------------------------
            function filename = getFullName(filename)
                FileOnPath = which(filename);
                if isempty(FileOnPath)
                    % construct full path to source file
                    filename = abspath(filename);
                    if isempty(dir(filename)) && ~isdir(filename)
                        % file does not exist. Terminate importation of file.
                        error(message('MATLAB:xlsread:FileDoesNotExist', filename));
                    end
                else
                    filename = FileOnPath;
                end
            end
            % -------------------------------------------------------------------------
        end
       