function [tVHAB_Objects, tConvertIDs] = extractXML(filepath, csValidTypes)
%% Extract xml data
% The first step is to read the xml data file and transform into a more
% human and matlab readable file for all components relevant to V-HAB.
% Everything else is neglected and not stored for further use

% Open the XML and go to the relevant section containing the V-HAB objects
DrawIoXML = tools.parseXML(filepath);
XML_VSYS = DrawIoXML.Children.Children;

% Initialize the struct which contains the draw IO components that will be
% translated into V-HAB objects
tVHAB_Objects = struct();
for iType = 1:length(csValidTypes)
    tVHAB_Objects.(csValidTypes{iType}) = cell(0);
end

% now loop through all xml elements and check whether they are a specified
% V-HAB object type, if that is the case store the information for further
% use
for iElement = 1:length(XML_VSYS)
    
    % Convert the XML Data structure into an easier to handle struct
    tStruct  = struct();
    csToPlot = cell(0);
    csToLog  = cell(0);
    for iAttribute = 1:length(XML_VSYS(iElement).Attributes)
        
        if strcmp(XML_VSYS(iElement).Attributes(iAttribute).Name, 'id') || strcmp(XML_VSYS(iElement).Attributes(iAttribute).Name, 'label')
            try
                sValue = XML_VSYS(iElement).Attributes(iAttribute).Value;
                fields = textscan(sValue,'%s','Delimiter','<');
                sValue = fields{1,1};
                sValue = sValue{1};
            catch
                sValue = XML_VSYS(iElement).Attributes(iAttribute).Value;
            end
            if ~isempty(sValue)
                tStruct.(XML_VSYS(iElement).Attributes(iAttribute).Name) = tools.normalizePath(sValue);
            else
                tStruct.(XML_VSYS(iElement).Attributes(iAttribute).Name) = sValue;
            end
        else
            if ~isempty(regexpi(XML_VSYS(iElement).Attributes(iAttribute).Value, 'PLOT_', 'once'))
                sValue = XML_VSYS(iElement).Attributes(iAttribute).Value(6:end);
                csToPlot{end+1} = XML_VSYS(iElement).Attributes(iAttribute).Name;
                
            elseif ~isempty(regexpi(XML_VSYS(iElement).Attributes(iAttribute).Value, 'LOG_', 'once'))
                sValue = XML_VSYS(iElement).Attributes(iAttribute).Value(5:end);
                csToLog{end+1} = XML_VSYS(iElement).Attributes(iAttribute).Name;
            else
                sValue = XML_VSYS(iElement).Attributes(iAttribute).Value;
            end
            tStruct.(XML_VSYS(iElement).Attributes(iAttribute).Name) = sValue;
        end
    end
    
    tStruct.csToPlot = csToPlot;
    tStruct.csToLog  = csToLog;
    
    for iChild = 1:length(XML_VSYS(iElement).Children)
        for iAttribute = 1:length(XML_VSYS(iElement).Children(iChild).Attributes)
            if strcmp(XML_VSYS(iElement).Children(iChild).Attributes(iAttribute).Name, 'parent')
                tStruct.ParentID = tools.normalizePath(XML_VSYS(iElement).Children(iChild).Attributes(iAttribute).Value);
            elseif strcmp(XML_VSYS(iElement).Children(iChild).Attributes(iAttribute).Name, 'source')
                tStruct.SourceID = tools.normalizePath(XML_VSYS(iElement).Children(iChild).Attributes(iAttribute).Value);
            elseif strcmp(XML_VSYS(iElement).Children(iChild).Attributes(iAttribute).Name, 'target')
                tStruct.TargetID = tools.normalizePath(XML_VSYS(iElement).Children(iChild).Attributes(iAttribute).Value);
            end
        end
    end
        
    % Now check if this struct is actually a V-HAB component
    if isfield(tStruct, 'sType')
        if any(strcmp(csValidTypes, tStruct.sType))
            
            tVHAB_Objects.(tStruct.sType){end+1} = tStruct;
            
            tConvertIDs.tIDtoLabel.(tStruct.id) = tStruct.label;
            tConvertIDs.tIDtoType.(tStruct.id) = tStruct.sType;
        else
            error('You specified the unknown type %s in the XML definition! See the csValidTypes variable from this function for possible types', tStruct.sType, csValidTypes{1})
        end
    end
end
end