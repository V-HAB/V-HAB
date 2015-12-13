%% NIST Scraper
% This script automatically downloads data from the National Institute of
% Standards and Technology (NIST) Chemistry Webbook. Using input parameters
% set at the beginning, the script dynamically generates a URL. This URL is
% used to download a comma separated value (CSV) file from NIST. The script
% then processes the CSV file into several files that match a data import
% function in the V-HAB matter table. 

% First we ask the user if he or she is really certain, that he or she
% wants to execute this script, since it will take some time, a good
% internet connection and it will overwrite the existing files.

sResult = questdlg(['Are you sure you want to run this script? ',...
                    'You will require an internet connection. ',...
                    'Depending on your connection speed, the script will run for several tens of minutes. ',...
                    'This script will overwrite all data files located in lib/+matterdata. ',...
                    'Are you sure you want to proceed?'], 'Warning','Proceed','Cancel','Proceed');

if strcmp(sResult, 'Cancel')
    fprintf('Script execution cancelled.\n');
    return;
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% This section contains data that needs to be modified if more        %%%
%%% substances are added for scraping                                   %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Set the ID to the CAS Registry Number for each substance that shall be
% scraped.
fID_Ar   = 7440371;
fID_CH4  =   74828;
fID_CH4O =   67561;
fID_CO   =  630080;
fID_CO2  =  124389;
fID_H2   = 1333740;
fID_H2O  = 7732185;
fID_N2   = 7727379;
fID_NH3  = 7664417;
fID_O2   = 7782447;

% For later processing, create a set of cells that contain strings of the
% chemical formula and the full name of each substance.
csSubstanceKeys  = {'Ar','CH4','CH4O','CO','CO2','H2','H2O','N2','NH3','O2'};
csSubstanceNames = {'Argon','Methane','Methanol','Carbon Monoxide','Carbon Dioxide','Hydrogen','Water','Nitrogen','Ammonia','Oxygen'};

tArgon          = struct('ID',fID_Ar,  'THigh', 700,'TLow', 84.00,'DHigh',1416);
tMethane        = struct('ID',fID_CH4, 'THigh', 625,'TLow', 91.00,'DHigh', 451);
tMethanol       = struct('ID',fID_CH4O,'THigh', 620,'TLow',176.00,'DHigh', 904);
tCarbonMonoxide = struct('ID',fID_CO,  'THigh', 500,'TLow', 67.00,'DHigh', 849);
tCarbonDioxide  = struct('ID',fID_CO2, 'THigh',1100,'TLow',217.00,'DHigh',1178);
tHydrogen       = struct('ID',fID_H2,  'THigh',1000,'TLow', 14.00,'DHigh',  77);
tWater          = struct('ID',fID_H2O, 'THigh',1275,'TLow',273.16,'DHigh',1218);
tNitrogen       = struct('ID',fID_N2,  'THigh',2000,'TLow', 63.15,'DHigh', 867);
tAmmonia        = struct('ID',fID_NH3, 'THigh', 700,'TLow',195.50,'DHigh', 732);
tOxygen         = struct('ID',fID_O2,  'THigh',1000,'TLow', 54.37,'DHigh',1237);


pData = containers.Map(csSubstanceKeys, {tArgon, tMethane, tMethanol, tCarbonMonoxide, ...
                                         tCarbonDioxide, tHydrogen, tWater, tNitrogen, ...
                                         tAmmonia, tOxygen}, 'UniformValues', false);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% End of user modified section                                        %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Preparations for scraping

% Setting the path where V-HAB expects the finished .csv data files to be
sPath = 'lib/+matterdata/';

% We need to let the matter table know, how many substances we scraped from
% NIST and which ones. So we'll just write this information to a .csv file.
iFileID = fopen([sPath,'NIST_Scraper_Data.csv'],'w+');
sOutputString_1 = '';
sOutputString_2 = '';
for iI = 1:length(csSubstanceKeys)
    sOutputString_1 = strcat(sOutputString_1, csSubstanceKeys{iI},',');
    sOutputString_2 = strcat(sOutputString_2, csSubstanceNames{iI},',');
end
sOutputString_1(end) = '';
sOutputString_2(end) = '';
fprintf(iFileID,'%s\n',sOutputString_1);
fprintf(iFileID,'%s',sOutputString_2);
fclose(iFileID);
                                     
                                     
oOptions = weboptions('Timeout',30);

pUnitConversionFactors = containers.Map(...
    {'-', 'K',    'MPa', 'kJ/kg',  'J/g*K', 'kg/m3', 'm3/kg', 'm/s',   'K/MPa', 'Pa*s', 'W/m*K'},...
    { 1 ,  1 , 1000000 ,   1000 ,    1000 ,      1 ,      1 ,    1 , 0.000001 ,     1 ,      1 });

pConvertedUnits = containers.Map(...
    {'MPa', 'kJ/kg',  'J/g*K', 'K/MPa'},...
    { 'Pa',  'J/kg', 'J/kg*K',  'K/Pa'});


% Calculate how many scrapes we still have to do

afIsochoricScrapes = zeros(1,pData.Count);

for iI = 1:pData.Count
    % Calculating the number of scrapes for the isochoric data. We want the
    % intervals between densities to be lower for low densities and higher
    % for high densities. 
    iCounter = 0;
    fValue = 0;
    fExponent = -7;
    while fValue < pData(csSubstanceKeys{iI}).DHigh
        iCounter = iCounter + 1;
        
        if fValue < 0.3
            fIncrement = exp(fExponent);
            fExponent  = fExponent + 0.1;
        %elseif fValue < 5
        %    fIncrement = 0.1;
        elseif fValue < 50
            fIncrement = 10;
        else
            fIncrement = 100;
        end
        
        fValue = fValue + fIncrement;
    end
    afIsochoricScrapes(iI) = iCounter;
end

iNumberOfIsoChors = sum(afIsochoricScrapes);
iNumberOfIsoBars  = 46;


iNumberOfScrapes = length(csSubstanceKeys) * iNumberOfIsoBars + iNumberOfIsoChors;
iCurrentScrape   = 1;
iErrorCounter = 0;

fStartTime = datetime();

%% Start looping through all substances
for iI = 1:length(csSubstanceKeys)
    sKey = csSubstanceKeys{iI};
    
    sIsochoricFileName = [sKey,'_Isochoric_DataFile.csv'];
    
    oDataFile = fopen([sPath, sIsochoricFileName],'w+');
    fclose(oDataFile);
    
    sIsochoricHeaderFileName = [sKey,'_Isochoric_HeaderFile.csv'];
    oHeaderFile = fopen([sPath, sIsochoricHeaderFileName],'w+');
    fclose(oHeaderFile);
    
    sIsobaricFileName = [sKey,'_Isobaric_DataFile.csv'];
    oDataFile = fopen([sPath, sIsobaricFileName],'w+');
    fclose(oDataFile);
    
    sIsobaricHeaderFileName = [sKey,'_Isobaric_HeaderFile.csv'];
    oHeaderFile = fopen([sPath, sIsobaricHeaderFileName],'w+');
    fclose(oHeaderFile);
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Getting the isochoric data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % We will get isochoric values from the NIST database for different
    % densities. We'll start low and then increase every iteration.
    fDensity = 0;
    % For the increase in density we (parially) use an exponential
    % function. Here are some initial values for this calculation.
    fExponent = -7;
    
    % This might be temporary. I don't know, if the headers actually change
    % within each substance. So I'll create a variable here, so I can
    % compare the old and new headers.
    csOldHeaders = cell(1);
    csOldHeaders{1} = 'First Run';
    
    % To reduce the computational load, we'll do some of these things only
    % the first time around for each substance. Therefore we need a boolean
    % variable that tells us, if this is the first run. 
    bFirstRun = true;
    
    % Begin iterating
    while fDensity < pData(sKey).DHigh
        % Console output, so we know how far along we are
        clc;
        fprintf('Scraping isochoric data for %s, scrape number %i\n', sKey, iCurrentScrape);
        fPercent = iCurrentScrape / iNumberOfScrapes * 100;
        iCurrentScrape = iCurrentScrape + 1;
        fprintf('Overall progress: %.2f %%\n',fPercent);
        
        % Now we dynamically assemble the URL for the current scrape
        sFreeVariable = ['D=',num2str(fDensity)];
    
        sURL = ['http://webbook.nist.gov/cgi/fluid.cgi?Action=Data&Wide=on&ID=C',...
                num2str(pData(sKey).ID),...
                '&Type=IsoChor&Digits=5&THigh='...
                num2str(pData(sKey).THigh),...
                '&TLow=',...
                num2str(pData(sKey).TLow),...
                '&TInc=5&',...
                sFreeVariable,...
                '&RefState=DEF&TUnit=K&PUnit=MPa&DUnit=kg%2Fm3&HUnit=kJ%2Fkg&WUnit=m%2Fs&VisUnit=Pa*s&STUnit=N%2Fm'
                ];
        
        % Actually getting the data from NIST
        sRawData  = webread(sURL,oOptions);
        
        % Now we do some replacing of strings so MATLAB knows what to do
        % with the information
        sRawData  = strrep(sRawData,'infinite','Inf');
        sRawData  = strrep(sRawData,'undefined','NaN');
        sRawData  = strrep(sRawData,'Cv','Isochoric Heat Capacity');
        sRawData  = strrep(sRawData,'Cp','Isobaric Heat Capacity');
        sRawData  = strrep(sRawData,'Sound Spd.','Speed Of Sound');
        sRawData  = strrep(sRawData,'Therm. Cond.','Thermal Conductivity');
        sRawData  = strrep(sRawData,'Viscosity','Dynamic Viscosity');
        
        % Extracting the header information from the top of the file
        cHeader   = textscan(sRawData,'%s',1,'delimiter','\n');
        csHeaders = textscan(cHeader{1}{1},'%s','delimiter','\t');
        csHeaders = csHeaders{1};
        csNewHeaders = csHeaders;
        
        % Checking if the headers for this scrape are the same as for the
        % previous one. If not, I don't know what to do yet, so just stop
        % doing everything. 
        if ~sum(strcmp(csNewHeaders, csOldHeaders)) && ~strcmp(csOldHeaders{1}, 'First Run')
            keyboard;
        end
        
        % Old and new are the same, so new is the new old...
        csOldHeaders = csNewHeaders;
        
        % Saving the raw data as text into a temporary file
        oTempFile = fopen('tmp.tsv','w+');
        fprintf(oTempFile, sRawData);
        fclose(oTempFile);
        
        % Before we can process the information in the temporary file, we
        % need to analyze the header. Isochoric data is tricky, because at
        % for a given temperature and pressure, there can be multiple
        % phases present. In the raw text file that we just saved, each row
        % has a specific value for temperature and pressure. Then the
        % matter values for the different phases is given in different
        % columns. The column headers look like this: 'Density (l, kg/m3)'
        % The lowercase 'L' is the indicator for the liquid phase here.
        % In the matter table, we would like the values in one row to be
        % for one phase, not all of them. So we will create two or three
        % sets of data, for each phase (liquid, vapor and liquid + vapor).
        
        % Assuming the text file format in terms of headers and column
        % numbers will be the same for every iteration for this substance,
        % we'll only do the following stuff once to save some computing 
        % time. 
        if bFirstRun
            afColumnPhases       = zeros(length(csHeaders), 1);
            csColumnNames        = cell(length(csHeaders), 1);
            csUnitNames          = cell(length(csHeaders), 1);
            
            for iK = 1:length(csHeaders)
                
                csTemp = strsplit(csHeaders{iK},' (');
                csColumnNames{iK} = csTemp{1};
                
                % Are there one or two items within the parentheses? If there
                % are two, they will be separated by a comma.
                cfResult = strfind(csTemp{2},',');
                if isempty(cfResult)
                    % There is only one item, so we chop off the right
                    % parethesis.
                    csTemp = strsplit(csTemp{2},')');
                    % The remaining item can either be a unit or a phase
                    % identifier. We check with our unit to factor conversion
                    % map, to see if it is a unit.
                    if any(strcmp(pUnitConversionFactors.keys,csTemp{1}))
                        % It is a unit, so we set the appropriate field in our
                        % unit names cell and then we are done, so we can skip
                        % to the next iteration of the for-loop.
                        csUnitNames{iK} = csTemp{1};
                        continue;
                    else
                        % It is a phase identifier, so we set our local
                        % variable accordingly.
                        sPhaseIdentifier = csTemp{1};
                    end
                else
                    % There are two items in the parentheses, first a phase
                    % identifier, then the unit. First we split them in in two
                    % at the comma.
                    csTemp = strsplit(csTemp{2},', ');
                    % In front of the comma is the phase identifier.
                    sPhaseIdentifier = csTemp{1};
                    % Behind the comma is the unit, from which we still have to
                    % chop off the right parenthesis.
                    csTemp = strsplit(csTemp{2},')');
                    csUnitNames{iK} = csTemp{1};
                end
                
                % Now we have all of the information nicely organized in some
                % cells, so we can apply our numeric code to the phases.
                switch sPhaseIdentifier
                    case 's'
                        afColumnPhases(iK) = 1;
                    case 'l'
                        afColumnPhases(iK) = 2;
                    case 'v'
                        afColumnPhases(iK) = 3;
                    case 'sc'
                        afColumnPhases(iK) = 4;
                    case 'l+v'
                        afColumnPhases(iK) = 5;
                end
                
            end
            
            iLiquidColumns = sum(afColumnPhases == 2);
            iVaporColumns  = sum(afColumnPhases == 3);
            
            iLiquidColumnsStart = find(afColumnPhases == 2, 1, 'first');
            iVaporColumnsStart  = find(afColumnPhases == 3, 1, 'first');
            
            % Don't really know what to do yet, if the columns don't match, so
            % for now we just throw our hands in the air as if we don't care.
            if ~(iLiquidColumns == iVaporColumns)
                keyboard();
            end
            
            % Only use the names and units we actually need
            % Cut off the end with the vapor columns, we'll use the liquid
            % units instead, they are the same (hopefully)
            csUnitNames(iVaporColumnsStart:end)    = [];
            csColumnNames(iVaporColumnsStart:end)  = [];
            % Remove the l+v units
            csUnitNames(3:iLiquidColumnsStart-1)   = [];
            csColumnNames(3:iLiquidColumnsStart-1) = [];
            
            csConvertedUnitNames = cell(iLiquidColumns + 2, 1);
            
            for iL = 1:(iLiquidColumns + 2)
                if ~isempty(csUnitNames{iL})
                    if ~(pUnitConversionFactors(csUnitNames{iL}) == 1)
                        csConvertedUnitNames{iL} = pConvertedUnits(csUnitNames{iL});
                    else
                        csConvertedUnitNames{iL} = csUnitNames{iL};
                    end
                end
            end
            
            csColumnNames{iL+1}        = 'Phase';
            csConvertedUnitNames{iL+1} = '-';
            
            
            %        Create a text file with the header information here
            oHeaderFile = fopen([sPath, sIsochoricHeaderFileName],'w+');
            sColumnFormat = '%s';
            for iL = 1:(length(csColumnNames)-1)
                sColumnFormat = strcat(sColumnFormat, ',%s');
            end
            sColumnFormat = strcat(sColumnFormat, '\n');
            fprintf(oHeaderFile,sColumnFormat,csColumnNames{:,1});
            fprintf(oHeaderFile,sColumnFormat,csConvertedUnitNames{:,1});
            fclose(oHeaderFile);
            
            % End of first run if-condition
            bFirstRun = false;
        end
        
        % Reading the temp file, staring at row nr. 2, so we skip the
        % header.
        mfRawData = dlmread('tmp.tsv','\t',2,0);
        
        mfProcessedData = zeros(length(mfRawData(:,1)) * 2, iLiquidColumns + 3 );
        
        for iL = 1:length(mfRawData(:,1))
            iIndex = iL*2;
            mfProcessedData(iIndex-1:iIndex, 1:2)         = [ mfRawData(iL,1:2); mfRawData(iL,1:2) ];
            mfProcessedData(iIndex-1, 3:2+iLiquidColumns) = mfRawData(iL, iLiquidColumnsStart:(iLiquidColumnsStart+iLiquidColumns-1));
            mfProcessedData(iIndex-1, 3+iLiquidColumns)   = 2;
            mfProcessedData(iIndex,   3:2+iVaporColumns)  = mfRawData(iL, iVaporColumnsStart:(iVaporColumnsStart+iVaporColumns-1));
            mfProcessedData(iIndex,   3+iVaporColumns)    = 3;
        end
        
        % Deleting all rows with pressures larger than 10 MPa = 100 bar.
        % These are currently not of interest. 
        mfProcessedData(mfProcessedData(:,strcmp(csColumnNames,'Pressure')) > 10,:) = [];
        
        for iL = 1:(iLiquidColumns + 2)
            if ~isempty(csUnitNames{iL})
                if ~(pUnitConversionFactors(csUnitNames{iL}) == 1)
                    mfProcessedData(:,iL) = mfProcessedData(:,iL) * pUnitConversionFactors(csUnitNames{iL});
                end
            end
        end
        
        % Writing the processed data to the end of the file.
        dlmwrite([sPath, sIsochoricFileName], mfProcessedData, '-append');
        
        % Last thing to do is increment the density value for the next
        % iteration.
        if fDensity < 5
            fDensity = fDensity + exp(fExponent);
            fExponent = fExponent + 0.1;
        %elseif fDensity < 5
        %    fDensity = fDensity + 0.1;
        elseif fDensity < 50
            fDensity = fDensity + 10;
        else
            fDensity = fDensity + 100;
        end
    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Getting the isobaric data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % We will get isobaric values from the NIST database for different
    % pressures. The pressure increment shall be lower for low
    % pressures and higher later on. So we initially set it to 0.01 MPa. 
    % ( ! Not Pa as in V-HAB ! ) In the following while-loop we can change
    % the increment according to the current pressure.
    fPressure = 0.01;
    
    % Right now, we're only interested in pressures up to 100 bars, which
    % is 10 MPa
    fMaximumPressure = 10;
    
    % This might be temporary. I don't know, if the headers actually change
    % within each substance. So I'll create a variable here, so I can
    % compare the old and new headers.
    csOldHeaders = cell(1);
    csOldHeaders{1} = 'First Run';
    
    % To reduce the computational load, we'll do some of these things only
    % the first time around for each substance. Therefore we need a boolean
    % variable that tells us, if this is the first run.
    bFirstRun = true;
    
    % Start iterating
    while fPressure < fMaximumPressure
        
        clc;
        fprintf('Scraping isobaric data for %s, scrape number %i\n', sKey, iCurrentScrape);
        fPercent = iCurrentScrape / iNumberOfScrapes * 100;
        iCurrentScrape = iCurrentScrape + 1;
        fprintf('Overall progress: %.2f %%\n',fPercent);
        
        sFreeVariable = ['P=',num2str(fPressure)];
    
        sURL = ['http://webbook.nist.gov/cgi/fluid.cgi?Action=Data&Wide=on&ID=C',...
                num2str(pData(sKey).ID),...
                '&Type=IsoBar&Digits=5&THigh='...
                num2str(pData(sKey).THigh),...
                '&TLow=',...
                num2str(pData(sKey).TLow),...
                '&TInc=5&',...
                sFreeVariable,...
                '&RefState=DEF&TUnit=K&PUnit=MPa&DUnit=kg%2Fm3&HUnit=kJ%2Fkg&WUnit=m%2Fs&VisUnit=Pa*s&STUnit=N%2Fm'
                ];
        
        sRawData = webread(sURL,oOptions);
        
        % Now we do some replacing of strings so MATLAB knows what to do
        % with the information
        sRawData = strrep(sRawData,'infinite','Inf');
        sRawData = strrep(sRawData,'undefined','NaN');
        sRawData = strrep(sRawData,'solid','1');
        sRawData = strrep(sRawData,'liquid','2');
        sRawData = strrep(sRawData,'vapor','3');
        sRawData = strrep(sRawData,'supercritical','4');
        sRawData = strrep(sRawData,'Cv','Isochoric Heat Capacity');
        sRawData = strrep(sRawData,'Cp','Isobaric Heat Capacity');
        sRawData  = strrep(sRawData,'Sound Spd.','Speed Of Sound');
        sRawData  = strrep(sRawData,'Therm. Cond.','Thermal Conductivity');
        sRawData  = strrep(sRawData,'Viscosity','Dynamic Viscosity');
        cHeader = textscan(sRawData,'%s',1,'delimiter','\n');
        csHeaders = textscan(cHeader{1}{1},'%s','delimiter','\t');
        csHeaders = csHeaders{1};
        csNewHeaders = csHeaders;
        
        % Checking if the headers for this scrape are the same as for the
        % previous one. If not, I don't know what to do yet, so just stop
        % doing everything.
        if ~sum(strcmp(csNewHeaders, csOldHeaders)) && ~strcmp(csOldHeaders{1}, 'First Run')
            keyboard;
        end
        
        % Old and new are the same, so new is the new old...
        csOldHeaders = csNewHeaders;
        
        % Saving the raw data as text into a temporary file
        oTempFile = fopen('tmp.tsv','w+');
        fprintf(oTempFile, sRawData);
        fclose(oTempFile);
        
        % Before we can process the information in the temporary file, we
        % need to analyze the header. 
        
        % Assuming the text file format in terms of headers and column
        % numbers will be the same for every iteration for this substance,
        % we'll only do the following stuff once to save some computing
        % time.
        if bFirstRun
            csColumnNames        = cell(length(csHeaders), 1);
            csUnitNames          = cell(length(csHeaders), 1);
            
            for iK = 1:length(csHeaders)
                
                cfResult = strfind(csHeaders{iK}, '(');
                if ~isempty(cfResult) && ~strcmp(csHeaders{iK}, 'Phase')
                    csTemp            = strsplit(csHeaders{iK},' (');
                    csColumnNames{iK} = csTemp{1};
                    csTemp            = strsplit(csTemp{2},')');
                    csUnitNames{iK}   = csTemp{1};
                else
                    csColumnNames{iK} = csHeaders{iK};
                    csUnitNames{iK}   = '-';
                end
            end
            
            csConvertedUnitNames = cell(length(csUnitNames), 1);
            
            for iL = 1:length(csUnitNames)
                if ~isempty(csUnitNames{iL})
                    if ~(pUnitConversionFactors(csUnitNames{iL}) == 1)
                        csConvertedUnitNames{iL} = pConvertedUnits(csUnitNames{iL});
                    else
                        csConvertedUnitNames{iL} = csUnitNames{iL};
                    end
                end
            end
            
            % Create a text file with the header information here
            oHeaderFile = fopen([sPath, sIsobaricHeaderFileName],'w+');
            sColumnFormat = '%s';
            for iL = 1:(length(csColumnNames)-1)
                sColumnFormat = strcat(sColumnFormat, ',%s');
            end
            sColumnFormat = strcat(sColumnFormat, '\n');
            fprintf(oHeaderFile,sColumnFormat,csColumnNames{:,1});
            fprintf(oHeaderFile,sColumnFormat,csConvertedUnitNames{:,1});
            fclose(oHeaderFile);
            
            % End of first run if-condition
            bFirstRun = false;

            
        end
        
        mfRawData = dlmread('tmp.tsv','\t',1,0);
        
        
        mfProcessedData = mfRawData;
        
        for iL = 1:length(mfProcessedData(1,:))
            if ~isempty(csUnitNames{iL})
                if ~(pUnitConversionFactors(csUnitNames{iL}) == 1)
                    mfProcessedData(:,iL) = mfProcessedData(:,iL) * pUnitConversionFactors(csUnitNames{iL});
                end
            end
        end

        
        dlmwrite([sPath, sIsobaricFileName], mfProcessedData, '-append');
        

        
        if fPressure < 0.2
            fPressureIncrement = 0.01;
        elseif fPressure < 1
            fPressureIncrement = 0.1;
        elseif fPressure < fMaximumPressure
            fPressureIncrement = 0.5;
        end
        
        fPressure = fPressure + fPressureIncrement;
        
    end
end

% Deleting the temporary file
delete(tmp.tsv);
    
% User output
fEndTime = datetime();
clc;
disp('Overall progress: 100.00 %');
disp(['Elapsed Time: ', char(fEndTime - fStartTime)]);
disp([num2str(iErrorCounter),' Errors!']);
