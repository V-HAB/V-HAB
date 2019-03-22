function aiIndex = find(this, cxItems, tFilter)
%FIND Returns log indexes of selected items
% This method returns an array of integers for the items that are contained
% in the cxItems variable. This variable can either be empty or a cell. The
% cell can contain either integers representing the index of the item
% within the log matrix, strings representing the label of the item or
% strings representing the name of the item. This method will detect which
% one it is and extract the index accordingly. Using the tFilter input
% argument, the selection of items can be reduced by providing a struct
% containing filter criteria. These can be any values of the fields of the
% tLogValues struct, however it is mostly used to filter by unit (key
% 'sUnit') or a specific system or object (key 'sObjectPath').
% If the cxItems input argument is left empty, all indexes will be
% returned, pending the application of any filters. 

%% Getting Indexes

% If cxItems is empty we'll just get all items in the log and return them.
if nargin < 2 || isempty(cxItems)
    aiIndex = 1:length(this.tLogValues);
    
elseif iscell(cxItems)
    % If csItems is a cell, we now translate all of the items in the cell
    % to indexes that are then returned via aiIndex. 
    % This is done prior to the application of any filters, because it
    % represents a pre-selection, just as if an array of integers had been
    % passed in directly.
    
    % Initializing some variables
    iLength  = length(cxItems);
    aiIndex = nan(1, iLength);
    
    % Getting the names and lables of all items in the current log object.
    csNames  = { this.tLogValues.sName };
    csLabels = { this.tLogValues.sLabel };
    
    % Getting the names and lables of all virtual items in the current log
    % object.
    csVirtualNames  = { this.tVirtualValues.sName };
    csVirtualLabels = { this.tVirtualValues.sLabel };
    
    
    % Now we'll loop through all of the items of cxItems and translate them
    % to integers representing their index in the log array.
    for iI = 1:iLength
        % If the item is an integer, then we can just write it directly to
        % aiIndex and continue on with the next item.
        if isnumeric(cxItems{iI})
            aiIndex(iI) = cxItems{iI};
            
            continue;
        end
        
        % Since the current item is a string, we now have to search through
        % the four cells containing all of the names and lables of all
        % items in the log until we find it.
        
        % First, we'll try the cell with the item names
        iIndex = find(strcmp(csNames, cxItems{iI}), 1, 'first');
        
        % If the previous search returned nothing, we'll try the virtual
        % values.
        if isempty(iIndex)
            iIndex = -1 * find(strcmp(csVirtualNames, cxItems{iI}), 1, 'first');
        end
        
        % If the previous search returned nothing, we'll try the labels.
        if isempty(iIndex)
            iIndex = find(strcmp(csLabels, cxItems{iI}(2:(end - 1))), 1, 'first');
        end
        
        % If the previous search returned nothing, we'll try the virtual
        % labels.
        if isempty(iIndex)
            iIndex = -1 * find(strcmp(csVirtualLabels, cxItems{iI}(2:(end - 1))), 1, 'first');
        end
        
        
        % If we still haven't found anything, there is no item in the log
        % with this name or lable, so we abort and tell the user.
        if isempty(iIndex)
            this.throw('find', 'Cannot find log value! String given: >>%s<< (if you were searching by label, pass in the label name enclosed by ", i.e. { ''"%s"'' })', cxItems{iI}, cxItems{iI});
        end
        
        % We can now write the found index to the return variable.
        aiIndex(iI) = iIndex;
    end
end

% If there is nothing to be logged, we also tell the user and return.
if isempty(aiIndex)
    this.out(4, 1, 'Nothing found in log.');
    return;
end

%% Applying Filters

% Now that we have our aiIndex array, we have to check if there are any
% filters to be applied and if yes, do so.
if nargin >= 3 && ~isempty(tFilter) && isstruct(tFilter)
    % The field names of the tFilter variable must correspond to field
    % names in the tLogValues struct.
    csFilters     = fieldnames(tFilter);
    
    % Initializing a boolean array that indicates which items are to be
    % deleted from aiIndex.
    abDeleteFinal = false(length(aiIndex), 1);
    
    % Now we loop through all of the filters to figure out, which items to
    % delete.
    for iF = 1:length(csFilters)
        % Initializing some local variables for the current filter. sFilter
        % is the field name in the tLogValues struct and xsValue is the
        % value that shall be filtered. This variable can be a string or a
        % cell. An example would be a filter for units 'W' and 'K', so
        % the resulting values would only be power and temperature values.
        sFilter = csFilters{iF};
        xsValue = tFilter.(sFilter);
        
        % If xsValue is a cell, we have to extract all items in it and do a
        % separate search for each of them.
        if iscell(xsValue)
            % First we'll get the values from each item in the tLogValues
            % struct in the according field.
            csLogValues = { this.tLogValues(aiIndex).(sFilter) }';
            
            % Now we're creating a boolean array of false values with the
            % same length.
            abNoDelete  = false(length(csLogValues), 1);
            
            % Looping throuhg the different filter criteria.
            for iV = 1:length(xsValue)
                % Using the 'or' operator and a string comparison between
                % the log values and the filter values, we can change the
                % values in the boolean array to true that we want to
                % filter.
                abNoDelete = abNoDelete | strcmp(csLogValues, xsValue{iV});
            end
            
            % As this array will be used to delete items from the aiIndex
            % array, we have to negate it.
            abDelete = ~abNoDelete;
        else
            % If there is only one value for this filter, we can write the
            % negated string comparison directly to the abDelete boolean
            % array.
            abDelete = ~strcmp({ this.tLogValues(aiIndex).(sFilter) }', xsValue);
        end
        
        % Now we use the 'or' operator again to update the abDeleteFinal
        % boolean array with the values to be deleted for the current
        % filter.
        abDeleteFinal = abDeleteFinal | abDelete;
        
    end
    
    % In case the filter has nothing to filter, we gather a bunch of
    % information to tell the user exactly where things went wrong. 
    if all(abDeleteFinal)
        sMessage = 'Filters:\n';
        for iFilter = 1:length(csFilters)
            if iscell(xsValue)
                sMessage = strcat(sMessage, csFilters{iFilter}, ' = {');
                for iFilterItem = 1:length(xsValue)
                    sMessage = strjoin({sMessage, [xsValue{iFilterItem}, ',']});
                end
                sMessage = sMessage(1:end-1);
                sMessage = strcat(sMessage, ' }\n');
            else
                sMessage = strjoin({[sMessage, csFilters{iFilter}], '=', xsValue, '\n'});
            end
        end
        
        if length(csFilters) > 1
            sMultiple = 's';
        else
            sMultiple = '';
        end
        
        sString = strcat('\nThere are no log items for the filter%s you have applied. \n', sMessage);
        
        this.throw(sString, sMultiple);
    end
    
    % Finally, we remove all unwanted items from the aiIndex array.
    aiIndex(abDeleteFinal) = [];
end
end
