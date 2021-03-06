function fProperty = findClosestValidMatterEntry(this, tParameters)
% findClosestValidMatterEntry is a helper to find the closes entry for the
% provided parameters. Different to the findProperty function it does not
% use interpolation, but simply looks for the closest valid value for the
% demanded property. Therefore, while findProperty can crash in edge cases
% this function will always provide valid matter values, although not for
% the exact provided conditions
%
%   FindProperty returns
%   fProperty - closest matching value for the demanded property which is
%   stored in the matter table
%
%   Input struct 'tParameters':
%
%   Mandatory parameters:
%   ---------------------
%   tParameters.sSubstance:         Name of the substance for which a
%                                   property desired. Has to be given in
%                                   short form, so 'CO2' instead of
%                                   'CarbonDioxide'
%   tParameters.sProperty:          Name of the property of sSubstance that
%                                   is desired. Is given in plain text, but
%                                   has to match the property name in the
%                                   data files (e.g. 'Pressure').
%   tParameters.sFirstDepName:      Name of the first dependency. Must be a
%                                   property of the substance given in the
%                                   data files.
%   tParameters.fFirstDepValue:     Value of the first dependency.
%   tParameters.sPhaseType:         Phase type of the given substance. Can
%                                   be 'solid', 'liquid', 'gas' or
%                                   'supercritical'
%
%   Optional parameters:
%   --------------------
%   tParameters.sSecondDepName:     Name of the second dependency. Must be
%                                   a property of the substance given in
%                                   the data files.
%   tParameters.fSecondDepValue:    Value of the second dependency.
%   tParameters.bUseIsobaricData:   A boolean variable that switches
%                                   between isochoric and isobaric data. If
%                                   not provided, the default value is
%                                   'false', so isochoric data will be
%                                   used.

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Checking inputs for correctness %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% To shorten the code lines in the rest of the function, we convert the
% input struct to local variables. While in the process, we can check which
% fields are actually present and throw some error messages if the data
% type is incorrect.

sSubstance = tParameters.sSubstance;
% Check if the input is a string
if ~ischar(sSubstance)
    this.throw('table:FindProperty','Substance name must be a string.');
end

sProperty = tParameters.sProperty;
% Check if the input is a string
if ~ischar(sProperty)
    this.throw('table:FindProperty','Property name must be a string.');
end

sFirstDepName = tParameters.sFirstDepName;
% Check if the input is a string
if ~ischar(sFirstDepName)
    this.throw('table:FindProperty','First dependency name must be a string.');
end

fFirstDepValue = tParameters.fFirstDepValue;
% Check if the input is a number
if ~isnumeric(fFirstDepValue)
    this.throw('table:FindProperty','First dependency value is not numeric.');
end

sPhaseType = tParameters.sPhaseType;
% Check if the input is a string
if ~ischar(sPhaseType)
    this.throw('table:FindProperty','Phase type must be a string.');
end

try
    sSecondDepName = tParameters.sSecondDepName;
    % Check if the input is a string
    if ~ischar(sSecondDepName)
        this.throw('table:FindProperty','Second dependency name must be a string.');
    end
    
    fSecondDepValue = tParameters.fSecondDepValue;
    % Check if the input is a number
    if ~isnumeric(fSecondDepValue)
        this.throw('table:FindProperty','Second dependency value is not numeric.');
    end
    % Seems the inputs are correct, we have two dependencies
    iDependencies = 2;
catch
    % The fields for the second dependency are empty, so we only have one.
    iDependencies = 1;
end

% We'll try to get the bUsieIsobaricData field, if that is not successfull,
% then the value is not given by the caller and the variable is set to the
% default value: false.
try
    bUseIsobaricData = tParameters.bUseIsobaricData;
    % Check if input is logical
    if ~islogical(bUseIsobaricData)
        this.throw('table:FindProperty','Isobaric data selector is not a boolean (logical).');
    end
catch
    bUseIsobaricData = true;
end


% Shortcut to matter data - should save some execution time
txMatterForSubstance = this.ttxMatter.(sSubstance);

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Deriving and setting search parameters %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Depending on which type of data we will be using, isochoric or isobaric,
% we need to set some variables accordingly, so we do have a giant
% if-condition with nearly the same code.
if txMatterForSubstance.bIndividualFile
    if bUseIsobaricData
        sTypeStruct = 'tIsobaricData';
        if strcmp(sProperty,'Heat Capacity')
            sProperty = 'Isobaric Heat Capacity';
        end
        sTypeString = 'isobaric';
    else
        sTypeStruct = 'tIsochoricData';
        if strcmp(sProperty,'Heat Capacity')
            sProperty = 'Isochoric Heat Capacity';
        end
        sTypeString = 'isochoric';
    end
end

% Setting the names of structs. This is a little stupid, but the phase type
% in the phase objects is just a lowercase word, like 'gas'. Since we're
% using the phase type as a struct name, it has to have the prefix 't' and
% per the V-HAB programming guidelines, the next letter has to be
% capitalized. So 'gas' would become 'tGas'. We'll create a variable here
% that does this conversion.
% Also, to generate the identification number for the interpolations, we
% need a numeric value for the phases, so since we're in a switch case here
% anyway, we'll just set it here as well.
% And we'll set some strings to provide the user with some nice debugging
% messages if he or she screws up...
switch sPhaseType
    case 'solid'
        sPhaseStructName = 'tSolid';
        iPhaseType       = 1;
        sPhaseAdjective  = 'solid';
    case 'liquid'
        sPhaseStructName = 'tLiquid';
        iPhaseType       = 2;
        sPhaseAdjective  = 'liquid';
    case 'gas'
        sPhaseStructName = 'tGas';
        iPhaseType       = 3;
    case 'supercritical'
        sPhaseStructName = 'tSupercritical';
        iPhaseType       = 4;
        sPhaseAdjective  = 'gaseous';
end


% Shorthand to save execution time!
if txMatterForSubstance.bIndividualFile
    txMatterForSubstanceAndType             = txMatterForSubstance.(sTypeStruct);
    txMatterForSubstanceAndTypeAndAggregate = txMatterForSubstanceAndType.(sPhaseStructName);
end

if ~base.oDebug.bOff
    % For debugging purposes, we'll get the unit names for the two
    % dependencies and put them into shorter-named variables for better
    % code readability.
    if txMatterForSubstance.bIndividualFile
        
        sFirstDepUnit  = txMatterForSubstanceAndType.tUnits.(sFirstDepName);
        
        if iDependencies == 2
            sSecondDepUnit = txMatterForSubstanceAndType.tUnits.(sSecondDepName);
        end
    end
    
    sReportString = 'Nothing to report.';
end

sPropertyNoSpaces = strrep(sProperty,' ','');

%TODO-SPEED maybe additional possibilities to save execution time, e.g. 
%     store everything in containers.Map and generate string keys or so?

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Finding properties in dedicated data file %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% See if this substance has an individual file
if txMatterForSubstance.bIndividualFile
    % Geting the column of the desired property
    iColumn = txMatterForSubstanceAndType.tColumns.(sPropertyNoSpaces);
    
    % if no column found, property is not in worksheet
    if isempty(iColumn)
        this.throw('table:FindProperty',sprintf('Cannot find property %s in worksheet %s', sProperty, sSubstance));
    end

    % Initialize array for checking if dependencies are out of
    % table value range
    abOutOfRange = [false; false];
    
    %---------------------------------------------------------------------%
    % Getting the first dependency and check for out of range
    %---------------------------------------------------------------------%
    sFirstDepNameNoSpaces = strrep(sFirstDepName,' ','');
    
    % get column of first dependency
    iColumnFirst = txMatterForSubstanceAndType.tColumns.(sFirstDepNameNoSpaces);
    % if properties are given 2 times (e.g. Temperature has C and K columns), second column is used
    if length(iColumnFirst) > 1
        iColumnFirst = iColumnFirst(2);
    end
    % if no column found, property is not in worksheet
    if isempty(iColumnFirst)
        this.throw('table:FindProperty',sprintf('Cannot find property %s in worksheet %s', sFirstDepName, sSubstance));
    end
    
    % look if data for first dependency is in range of table
    % if not in range, first look if data is given in worksheet MatterData before interpolate
    fMin = txMatterForSubstanceAndTypeAndAggregate.ttExtremes.(['t',sFirstDepNameNoSpaces]).Min;
    fMax = txMatterForSubstanceAndTypeAndAggregate.ttExtremes.(['t',sFirstDepNameNoSpaces]).Max;
    
    if fFirstDepValue > fMax
        % First dependency is greater than max value in table
        % set dependency equal max table value
        fFirstDepValue = fMax;
        abOutOfRange(1) = true;
    elseif fFirstDepValue < fMin
        % First dependency is less than min value in table
        % set dependency equal min table value
        fFirstDepValue = fMin;
        abOutOfRange(1) = true;
    end
    
    %-----------------------------------------------------------------%
    % Only one dependency is given
    %-----------------------------------------------------------------%
    
    if iDependencies == 1
        
        % Check and see, if this interpolation has been done before and
        % use those values for better performance.

        % First we need to create the unique ID for this specific
        % interpolation to see, if it already exists.
        sID = sprintf('ID%i', iColumnFirst * 10000 + iPhaseType);



        % The interpolation function does not yet exist, so we have
        % to go and run the interpolation.

        % create temporary array because scatteredInterpolant
        % doesn't allow NaN values
        afTemporary = txMatterForSubstanceAndTypeAndAggregate.mfData(:,[iColumn, iColumnFirst]);

        % Now we remove all rows that contain NaN values
        afTemporary(any(isnan(afTemporary), 2), :) = [];

        % Only unique values are needed (also scatteredInterpolant
        % would give out a warning in that case)
        afTemporary = unique(afTemporary,'rows');
        % Sometimes there are also multiple values for the same
        % combination of dependencies. Here we get rid of those
        % too.
        [ ~, aIndices ] = unique(afTemporary(:, 2), 'rows');
        afTemporary = afTemporary(aIndices, :);

        % Now we get the property closest to the provided dependencies by
        % calculating the root square sum over all available values for the
        % dependencies
        afRootSquareSum = ((afTemporary(:,2) - fFirstDepValue).^2).^(1/2);

        % Now we find the entry with the smallest error
        abSmallestErrorEntry = (afRootSquareSum == min(afRootSquareSum));

        % and get the property value for that entry
        fProperty = afTemporary(abSmallestErrorEntry,1);
        
        if length(fProperty) > 1
            fProperty = fProperty(1);
        end
        
    else
        
        %-----------------------------------------------------------------%
        % Two dependencies are given.
        % Getting the second dependency and check for out of range
        %-----------------------------------------------------------------%
        sSecondDepNameNoSpaces = strrep(sSecondDepName,' ','');
        
        
        % get column of second dependency
        iColumnSecond = txMatterForSubstanceAndType.tColumns.(sSecondDepNameNoSpaces);
        
        % if no column found, property is not in worksheet
        if isempty(iColumnSecond)
            this.throw('table:FindProperty',sprintf('Cannot find property %s in worksheet %s', sSecondDepName, sSubstance));
        end
        
        % look if data for second dependency is in range of table
        % if not in range, first look if data is given in worksheet MatterData before interpolate
        fMin = txMatterForSubstanceAndTypeAndAggregate.ttExtremes.(['t',sSecondDepNameNoSpaces]).Min;
        fMax = txMatterForSubstanceAndTypeAndAggregate.ttExtremes.(['t',sSecondDepNameNoSpaces]).Max;
        if fSecondDepValue > fMax
            % Second dependency is greater than max value in table
            % set dependency equal max table value
            fSecondDepValue = fMax;
            abOutOfRange(2) = true;
        elseif fSecondDepValue < fMin
            % Second dependency is less than min value in table
            % set dependency equal min table value
            fSecondDepValue = fMin;
            abOutOfRange(2) = true;
        end
        
        % Check and see, if this interpolation has been
        % done before and use those values for better
        % performance.
        
        % First we need to create the unique ID for
        % this specific interpolation to see, if it
        % already exists.
        sID = sprintf('ID%i', iColumnFirst * 10000 + iColumnSecond * 100 + iPhaseType);
        
        % The interpolation function does not yet
        % exist, so we have to go and run the
        % interpolation.

        % create temporary array because scatteredInterpolant doesn't allow NaN values
        afTemporary = txMatterForSubstanceAndTypeAndAggregate.mfData(:,[iColumn, iColumnFirst, iColumnSecond]);

        % Now we remove all rows that contain NaN values
        afTemporary(any(isnan(afTemporary), 2), :) = [];

        % Only unique values are needed (also scatteredInterpolant would give out a warning in that case)
        afTemporary = unique(afTemporary,'rows');
        % Sometimes there are also multiple values for
        % the same combination of dependencies. Here we
        % get rid of those too.
        [ ~, aIndices ] = unique(afTemporary(:, [2 3]), 'rows');
        afTemporary = afTemporary(aIndices, :);
        
        % Now we get the property closest to the provided dependencies by
        % calculating the root square sum over all available values for the
        % dependencies
        afRootSquareSum = ((afTemporary(:,2) - fFirstDepValue).^2 + (afTemporary(:,3) - fSecondDepValue).^2).^(1/2);
        
        % Now we find the entry with the smallest error
        abSmallestErrorEntry = (afRootSquareSum == min(afRootSquareSum));
        
        % and get the property value for that entry
        fProperty = afTemporary(abSmallestErrorEntry,1);
        
        if length(fProperty) > 1
            fProperty = fProperty(1);
        end
        
        if ~base.oDebug.bOff
            % Doing some nice user interface output messages.
            if ~(abOutOfRange(1) || abOutOfRange(2))
                sReportString = 'Both dependencies in range. Tried to get value by interpolation.';
            else
                % To make the code more readable, we first create some
                % local variables with short names.
                sActualFirstDepValue  = sprintf('%f',tParameters.fFirstDepValue);
                sUsedFirstDepValue    = sprintf('%f',fFirstDepValue);
                sActualSecondDepValue = sprintf('%f',tParameters.fSecondDepValue);
                sUsedSecondDepValue   = sprintf('%f',fSecondDepValue);
                
                if abOutOfRange(1) && ~abOutOfRange(2)
                    sReportString = ['The value given for ',sFirstDepName,' (',sActualFirstDepValue,' ',sFirstDepUnit,') is out of Range. ',...
                        'Used ',sUsedFirstDepValue,' ',sFirstDepUnit,' instead and tried to get best possible in-range value by interpolation.'];
                elseif ~abOutOfRange(1) && abOutOfRange(2)
                    sReportString = ['The value given for ',sSecondDepName,' (',sActualSecondDepValue,' ',sSecondDepUnit,') is out of Range. ',...
                        'Used ',sUsedSecondDepValue,' ',sSecondDepUnit,' instead and tried to get best possible in-range value by interpolation.'];
                else
                    sReportString = ['The values given for both dependencies (',sFirstDepName,' (',sActualFirstDepValue,'), ',...
                        sSecondDepName,' (',sActualSecondDepValue,' ',sSecondDepUnit,')) are out of Range. ',...
                        'Used ',sUsedFirstDepValue,' ',sFirstDepUnit,' and ',sUsedSecondDepValue,' ',sSecondDepUnit,' instead and tried to get best possible in-range value by interpolation.'];
                end
            end
        end
        
    end
    
    
else
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Finding properties in generic MatterData file %%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Geting the column of the desired property
    iColumn = txMatterForSubstance.tColumns.(sPropertyNoSpaces);
    
    % if no column found, property is not in worksheet
    if isempty(iColumn)
        this.throw('table:FindProperty',sprintf('Cannot find %s for %s (%s)', sProperty, sSubstance, sPhaseType));
    end

        fProperty = txMatterForSubstance.ttxPhases.(sPhaseStructName).(sPropertyNoSpaces);
        if isempty(fProperty) || isnan(fProperty)
            this.throw('findProperty', 'Error using findProperty. The matter data for %s (%s) does not include a value for %s.', sSubstance, sPhaseType, sProperty);
        else
            if ~base.oDebug.bOff
                sReportString = 'Just took the value from the ''Matter Data'' worksheet.';
            end
        end
    
    
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Check to see if what we got in the end is an actual value %%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if isnan(fProperty) || isempty(fProperty)
    if ~base.oDebug.bOff
        this.warn('findProperty', 'Error using findProperty. No valid value for %s %s of %s (%s) found in matter table. %s\n', sTypeString, sProperty, sSubstance, sPhaseType, sReportString);
        %     keyboard();
        this.throw('findProperty', 'Error using findProperty. No valid value for %s %s of %s (%s) found in matter table. %s\n', sTypeString, sProperty, sSubstance, sPhaseType, sReportString);
    else
        this.warn('findProperty', 'Error using findProperty. No valid value for %s %s of %s (%s) found in matter table.\n', sTypeString, sProperty, sSubstance, sPhaseType);
        %     keyboard();
        this.throw('findProperty', 'Error using findProperty. No valid value for %s %s of %s (%s) found in matter table.\n', sTypeString, sProperty, sSubstance, sPhaseType);

    end
    
end

end