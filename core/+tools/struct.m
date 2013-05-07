classdef struct
    %STRUCT helper methods
    
    methods (Static = true)
        function tStruct = foreach(tStruct, callBack)
            csFields = fieldnames(tStruct);
            iArgOut  = nargout(callBack);
            
            for iI = 1:length(csFields)
                % Special handling of anonymous function handles
                if iArgOut == -1
                    try
                        xVal = callBack(csFields{iI}, tStruct.(csFields{iI}));
                        
                        tStruct.(csFields{iI}) = xVal;
                        
                    catch %#ok<CTCH>
                        callBack(csFields{iI}, tStruct.(csFields{iI}));
                        
                    end
                    
                elseif iArgOut == 1
                    tStruct.(csFields{iI}) = callBack(csFields{iI}, tStruct.(csFields{iI}));
                    
                else
                    callBack(csFields{iI}, tStruct.(csFields{iI}));
                    
                end
            end
        end
        
        function tOrg = mergeStructs(tOrg, tNew)
            % Merges structs
            %
            %TODO
            %   - possible to define if deep or shallow merge? See jQuery
            %     merge for arrays :-)
            
            csFields = fieldnames(tNew);

            % Loop tNew and merge on tOrg
            for iI = 1:size(csFields, 1)
                sField = csFields{iI, 1};

                % Both are structs - recursive call to updateStruct
                if isfield(tOrg, sField) && isstruct(tOrg.(sField)) && isstruct(tNew.(sField))
                    tOrg.(sField) = tools.struct.mergeStructs(tOrg.(sField), tNew.(sField));

                % Ok, either tOrg or tNew is NO struct (or both), so tNew
                % overwrites he tOrg value (even if tOrg was a struct ...)
                else
                    tOrg.(sField) = tNew.(sField);

                end
            end
        end
    end
end