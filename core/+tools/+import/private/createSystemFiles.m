function createSystemFiles(tVHAB_Objects, csPhases, csF2F, csSystems, sPath, sSystemLabel, tConvertIDs)
% This function loops through all systems and defines the necessary V-HAB
% code for them

for iSystem = 1:length(tVHAB_Objects.System)
    
    tCurrentSystem = tVHAB_Objects.System{iSystem};
    sSystemName = tools.normalizePath(tCurrentSystem.label);
    sSystemFile = fopen([sPath, filesep, sSystemName, '.m'], 'w');
    
    fprintf(sSystemFile, ['\n classdef ', sSystemName,' < vsys\n']);
    fprintf(sSystemFile, '\n properties\n');

    if ~isempty(tCurrentSystem.Human)
        tHuman = tCurrentSystem.Human{1};
        fprintf(sSystemFile, ['iCrewMembers = ',tHuman.iNumberOfCrew,';\n']);
    else
        fprintf(sSystemFile, 'iCrewMembers = 0;\n');
    end
    % If plants are used add the respective properties for them
    if ~isempty(tCurrentSystem.Plants)
        if length(tCurrentSystem.Plants) > 1
            error('Currently the GUI only allows the addition of one plant module, if you want to add more you have to adjust the properties in the code/ define the other plant cultures in the code')
        end
        tPlants = tCurrentSystem.Plants{1};
        % All plants for which models are available are used. The values
        % for lighting etc are based on BVAD table 4-117 and 4.96
        % Areas are assumed per crew member and are designed to supply a
        % nearly closed diet for the crew. 0 days emerge time are assumed
        % because sprouts are assumed to be grown outside the PGC and then
        % be transplanted once emerged
        
        fprintf(sSystemFile, ['\n iAssumedPreviousPlantGrowthDays = ', tPlants.iAssumedPreviousPlantGrowthDays,';\n']);
        fprintf(sSystemFile, ' csPlants        = {''Sweetpotato'',   ''Whitepotato'',  ''Rice''  , ''Drybean'' , ''Soybean'' , ''Tomato''  , ''Peanut''  , ''Lettuce'' ,	''Wheat''};\n');
        
        csVariable  = {'mfPlantArea', 'mfHarvestTime', 'miSubcultures', 'mfPhotoperiod', 'mfPPFD', 'mfEmergeTime'};
        csUnit      = {'m^2 / CM', 'days', '-', 'h/day', 'micromol/m^2 s', 'days'};
        
        for iVariable = 1:length(csVariable)
            sVariable = erase(tPlants.(csVariable{iVariable}), ' ');
            csCurrentVariable = strsplit(sVariable, ',');
            fprintf(sSystemFile, [' ',csVariable{iVariable},'     = [ ',csCurrentVariable{1},'           ,   ',csCurrentVariable{2},'            ,  ',csCurrentVariable{3},'       , ',csCurrentVariable{4},'        , ',csCurrentVariable{5},'         , ',csCurrentVariable{6},'         , ',csCurrentVariable{7},'        , ',csCurrentVariable{8},'         ,   ',csCurrentVariable{9},'];       	%% ', csUnit{iVariable},'\n']);
        end
        
        fprintf(sSystemFile, 'mfInedibleGrowth= [ 225         ,   90.25        ,  211.58  , 150       , 68.04     , 127.43    , 168.75    , 7.3       ,   300];      	%% g/(m^2 d)\n');
        fprintf(sSystemFile, 'mfEdibleGrowth  = [ 24.7        ,   105.3        ,  10.3    , 11.11     , 5.04      , 173.76    , 5.96      , 131.35    ,   22.73];      	%% g/(m^2 d)\n');
        
        fprintf(sSystemFile, '%% plant lighting energy demand in W during the photoperiod\n');
        fprintf(sSystemFile, 'mfPlantLightEnergy;\n');
        fprintf(sSystemFile, 'tfPlantControlParameters;\n');
    end
    fprintf(sSystemFile, 'end\n \n methods\n');

    fprintf(sSystemFile, ['     function this = ', sSystemName,'(oParent, sName)\n']);
    if ~isempty(tCurrentSystem.fTimeStep)
        fprintf(sSystemFile, ['          this@vsys(oParent, sName, ', tCurrentSystem.fTimeStep,');\n']);
    else
        fprintf(sSystemFile, '          this@vsys(oParent, sName);\n');
    end
    fprintf(sSystemFile, '\n');
    
    % Add subsystems
    csChildren = tCurrentSystem.csChildren;
    for iChild = 1:length(csChildren)
        sChildName = tools.normalizePath(tCurrentSystem.csChildren{iChild}.label);
        fprintf(sSystemFile, ['             DrawIoImport.', sSystemLabel, '.systems.', sChildName, '(this, ''', sChildName,''');\n']);
    end
    
    for iHuman = 1:length(tCurrentSystem.Human)
        tHuman = tCurrentSystem.Human{iHuman};
        
        sCrewPlaner = ['%% create Crew Planner for Human ', tHuman.label, '\n'];
        sCrewPlaner = [sCrewPlaner, 'iLengthOfMission = ', tVHAB_Objects.Setup{1}.fSimTime, ' / (24 * 3600);\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'iEvent = 1;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'ctEvents = cell.empty(2 * iLengthOfMission,0);\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'for iDay = 1:iLengthOfMission\n']; %#ok
            
        sCrewPlaner = [sCrewPlaner, 'ctEvents{iEvent}.State            = 2;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'ctEvents{iEvent}.Start            = ((iDay-1) * 24 +  9) * 3600;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'ctEvents{iEvent}.End              = ((iDay-1) * 24 +  9 + ', tHuman.fExercise,') * 3600;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'ctEvents{iEvent}.Started          = false;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'ctEvents{iEvent}.Ended            = false;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'ctEvents{iEvent}.VO2_percent      = 0.5;\n\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'iEvent = iEvent + 1;\n\n']; %#ok

        sCrewPlaner = [sCrewPlaner, 'ctEvents{iEvent}.State            = 0;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'ctEvents{iEvent}.Start            = ((iDay-1) * 24 +  14) * 3600;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'ctEvents{iEvent}.End              = ((iDay-1) * 24 +  14 + ',tHuman.fSleep,') * 3600;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'ctEvents{iEvent}.Started          = false;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'ctEvents{iEvent}.Ended            = false;\n\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'iEvent = iEvent + 1;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'end\n\n']; %#ok

        sCrewPlaner = [sCrewPlaner, 'tMealTimes.Breakfast  = 0*3600;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'tMealTimes.Lunch      = 6*3600;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'tMealTimes.Dinner     = 15*3600;\n\n']; %#ok
       
        sCrewPlaner = [sCrewPlaner, 'txCrewPlaner.ctEvents 	= ctEvents;\n']; %#ok
        sCrewPlaner = [sCrewPlaner, 'txCrewPlaner.tMealTimes   = tMealTimes;\n\n']; %#ok
        
        fprintf(sSystemFile, sCrewPlaner);
        
        
        fprintf(sSystemFile, ['for iCrewMember = 1:', tHuman.iNumberOfCrew, '\n']);
        fprintf(sSystemFile,  '     txCrewPlaner.ctEvents = ctEvents(:, iCrewMember);\n');
        fprintf(sSystemFile,  '     txCrewPlaner.ctEvents = ctEvents(:, iCrewMember);\n');
        fprintf(sSystemFile,  '     txCrewPlaner.tMealTimes = tMealTimes;\n');
        fprintf(sSystemFile,  '     components.matter.DetailedHuman.Human(this, [''Human_'', num2str(iCrewMember)], txCrewPlaner, 60);\n');
        fprintf(sSystemFile,  '     clear txCrewPlaner;\n');
        fprintf(sSystemFile,  'end\n');
    end
    
    fprintf(sSystemFile, '\n');
    if ~isempty(tCurrentSystem.Plants)
        tPlants = tCurrentSystem.Plants{1};
        fprintf(sSystemFile, '%%%% Plants \n');
        if strcmp(tPlants.bMultiplyPlantAreaWithNumberOfCrew, 'true') || strcmp(tPlants.bMultiplyPlantAreaWithNumberOfCrew, '1')
            fprintf(sSystemFile, 'this.mfPlantArea = this.mfPlantArea .* this.iCrewMembers;\n');
        end
        fprintf(sSystemFile, '\n');
        fprintf(sSystemFile, 'tInput = struct();\n');
        fprintf(sSystemFile, 'abEmptyPlants = false(1, length(this.csPlants));\n');
        fprintf(sSystemFile, 'for iPlant = 1:length(this.csPlants)\n');
        fprintf(sSystemFile, '	mfFirstSowTimeInit = 0 : this.mfHarvestTime(iPlant) / this.miSubcultures(iPlant) : this.mfHarvestTime(iPlant);\n');
        fprintf(sSystemFile, '	mfFirstSowTimeInit = mfFirstSowTimeInit - this.iAssumedPreviousPlantGrowthDays;\n');
        fprintf(sSystemFile, '	mfFirstSowTimeInit(end) = [];\n');
        fprintf(sSystemFile, '	mfPlantTimeInit     = zeros(length(mfFirstSowTimeInit),1);\n');
        fprintf(sSystemFile, '	mfPlantTimeInit(mfFirstSowTimeInit < 0) = -mfFirstSowTimeInit(mfFirstSowTimeInit < 0);\n');
        fprintf(sSystemFile, '	 mfPlantTimeInit = mod(mfPlantTimeInit, this.mfHarvestTime(iPlant));\n');
        fprintf(sSystemFile, '\n');
        fprintf(sSystemFile, '	 for iSubculture = 1:this.miSubcultures(iPlant)\n');
        fprintf(sSystemFile, '	 	if this.mfPlantArea(iPlant) == 0\n');
        fprintf(sSystemFile, '	 		abEmptyPlants(iPlant) = true;\n');
        fprintf(sSystemFile, '	 		continue;\n');
        fprintf(sSystemFile, '	 	end\n');
        fprintf(sSystemFile, '	 	tInput(iPlant, iSubculture).sName            = [this.csPlants{iPlant}, ''_'', num2str(iSubculture)];\n');
        fprintf(sSystemFile, '	 	tInput(iPlant, iSubculture).sPlantSpecies    = this.csPlants{iPlant};\n');
        fprintf(sSystemFile, '	 	tInput(iPlant, iSubculture).fGrowthArea      = this.mfPlantArea(iPlant) ./ this.miSubcultures(iPlant); %% m^2\n');
        fprintf(sSystemFile, '	 	tInput(iPlant, iSubculture).fHarvestTime     = this.mfHarvestTime(iPlant); %% days\n');
        fprintf(sSystemFile, '	 	tInput(iPlant, iSubculture).fEmergeTime      = this.mfEmergeTime(iPlant); %% days\n');
        fprintf(sSystemFile, '	 	tInput(iPlant, iSubculture).fPPFD            = this.mfPPFD(iPlant); %% micromol/m^2s\n');
        fprintf(sSystemFile, '	 	tInput(iPlant, iSubculture).fPhotoperiod     = this.mfPhotoperiod(iPlant); %% h\n');
        fprintf(sSystemFile, '	 	tInput(iPlant, iSubculture).iConsecutiveGenerations     = 1 + ceil(iLengthOfMission / this.mfHarvestTime(iPlant));\n');
        fprintf(sSystemFile, '	 	tInput(iPlant, iSubculture).mfSowTime                   = zeros(1, tInput(iPlant, iSubculture).iConsecutiveGenerations);\n');
        fprintf(sSystemFile, '	 	if mfFirstSowTimeInit(iSubculture) > 0\n');
        fprintf(sSystemFile, '	 		tInput(iPlant, iSubculture).mfSowTime(1) = mfFirstSowTimeInit(iSubculture) * 24 * 3600;\n');
        fprintf(sSystemFile, '	 	end\n');
        fprintf(sSystemFile, '	 	\n');
        fprintf(sSystemFile, '	 	components.matter.PlantModule.PlantCulture(...\n');
        fprintf(sSystemFile, '	 		this, ...\n');
        fprintf(sSystemFile, '	 		tInput(iPlant, iSubculture).sName,...\n');
        fprintf(sSystemFile, ['	 		',tPlants.fTimeStep,',...\n']);
        fprintf(sSystemFile, '	 		tInput(iPlant, iSubculture),...\n');
        fprintf(sSystemFile, '	 		mfPlantTimeInit(iSubculture));\n');
        fprintf(sSystemFile, '	 end\n');
        fprintf(sSystemFile, 'end\n');
        fprintf(sSystemFile, '\n');
        fprintf(sSystemFile, 'this.csPlants(abEmptyPlants)        = [];');
        fprintf(sSystemFile, 'this.mfHarvestTime(abEmptyPlants)   = [];');
        fprintf(sSystemFile, 'this.miSubcultures(abEmptyPlants)   = [];');
        fprintf(sSystemFile, 'this.mfPhotoperiod(abEmptyPlants)   = [];');
        fprintf(sSystemFile, 'this.mfPPFD(abEmptyPlants)          = [];');
        fprintf(sSystemFile, 'this.mfEmergeTime(abEmptyPlants)    = [];');
        fprintf(sSystemFile, 'this.mfInedibleGrowth(abEmptyPlants)= [];');
        fprintf(sSystemFile, 'this.mfEdibleGrowth(abEmptyPlants)  = [];');
    end
            
    fprintf(sSystemFile, '\n');
    
    for iCCAA = 1:length(tCurrentSystem.CCAA)
        tCCAA = tCurrentSystem.CCAA{iCCAA};
        fprintf(sSystemFile, ['             components.matter.CCAA.CCAA(this, ''', tCCAA.label, ''', ', tCCAA.fTimeStep, ', ', tCCAA.fCoolantTemperature, ', [], ''',  tCCAA.sCDRA, ''');\n']);
        
        if isfield(tCCAA, 'sLoadAlternativeProperties')
            fprintf(sSystemFile, ['             load(', tCCAA.sLoadAlternativeProperties,');\n']);
            fprintf(sSystemFile, ['             this.toChildren.', tCCAA.label,'.setParameterOverwrite(tParameters);\n']);
        end
    end
    
    fprintf(sSystemFile, '\n');
    
    for iOGA = 1:length(tCurrentSystem.OGA)
        tOGA = tCurrentSystem.OGA{iOGA};
        fprintf(sSystemFile, ['             components.matter.OGA.OGA(this, ''', tOGA.label, ''', ',tOGA.fTimeStep,', ', tOGA.fOutletTemperature, ');\n']);
    end
    
    fprintf(sSystemFile, '\n');
    
    for iCDRA = 1:length(tCurrentSystem.CDRA)
        tCDRA = tCurrentSystem.CDRA{iCDRA};
        fprintf(sSystemFile, ['             components.matter.CDRA.CDRA(this, ''', tCDRA.label, ''', []);\n']);
    end
    
    fprintf(sSystemFile, '\n');
    
    for iSCRA = 1:length(tCurrentSystem.SCRA)
        tSCRA = tCurrentSystem.SCRA{iSCRA};
        fprintf(sSystemFile, ['             components.matter.SCRA.SCRA(this, ''', tSCRA.label, ''', ',tSCRA.fTimeStep,', ', tSCRA.fCoolantTemperature, ');\n']);
    end
    
    fprintf(sSystemFile, '\n');
    
    for iSubsystem = 1:length(tCurrentSystem.Subsystem)
        tSubsystem = tCurrentSystem.Subsystem{iSubsystem};
        
        sInput = 'tInput = struct();\n';
        
        csFields = fieldnames(tSubsystem);
        csStandardFields = {'id', 'label', 'sSubsystemPath', 'sType', 'csToPlot', 'csToLog', 'ParentID', 'fTimeStep', 'Input', 'Output'};
        for iField = 1:length(csFields)
            bStandard = false;
            for iStandardField = 1:length(csStandardFields)
                if strcmp(csFields{iField}, csStandardFields{iStandardField})
                    bStandard = true;
                end
            end
            
            if ~bStandard
                
                abLetters = isletter(tSubsystem.(csFields{iField}));
                
                bString = false;
                if strcmp(tSubsystem.(csFields{iField}), 'inf')
                    bString = false;
                elseif sum(abLetters) > 1 && length(abLetters) > 1
                    bString = true;
                elseif sum(abLetters) == 1 && length(abLetters) == 1
                    bString = false;
                end
                
                if bString
                    sInput = [sInput, 'tInput.', csFields{iField}, ' = ''',tSubsystem.(csFields{iField}), ''';\n '];
                else
                    sInput = [sInput, 'tInput.', csFields{iField}, ' = ',tSubsystem.(csFields{iField}), ';\n '];
                end
                
            end
        end
        
        
        fprintf(sSystemFile, sInput);
        fprintf(sSystemFile, ['             ', tSubsystem.sSubsystemPath ,'(this, ''', tSubsystem.label, ''', ', tSubsystem.fTimeStep, ', tInput);\n\n']);
    end
    
    fprintf(sSystemFile, '     	end\n\n');
    
    % Create Matter Structure
    fprintf(sSystemFile, '     	function createMatterStructure(this)\n');
    fprintf(sSystemFile, '          createMatterStructure@vsys(this);\n\n');
    
    % Creates the stores and all parts within them (phases and P2Ps)
    tCurrentSystem = createStores(tCurrentSystem, csPhases, sSystemFile, tConvertIDs);
    
    % Creates the F2Fs
    tCurrentSystem = createF2Fs(tCurrentSystem, csF2F, sSystemFile);
    
    % Create Branches and Interfaces
    createBranches(tCurrentSystem, tVHAB_Objects, csSystems, sSystemFile);
    
    %% Create Thermal Structure
    createThermalStructure(tCurrentSystem, csPhases, sSystemFile);
    
    %% Create Solver Structure
    tCurrentSystem = createSolverStructure(tCurrentSystem, csPhases, sSystemFile);
    
    %% Finish system definition
    fprintf(sSystemFile, 'methods (Access = protected)\n');
    fprintf(sSystemFile, '      function exec(this, ~)\n');
    fprintf(sSystemFile, '          exec@vsys(this);\n');
    fprintf(sSystemFile, '\n');
    
    if isfield(tCurrentSystem, 'exec')
        for iExecCode = 1:length(tCurrentSystem.exec)
            sString = tCurrentSystem.exec{iExecCode};
            abNonASCII = sString > 127;
            sString(abNonASCII) = ' ';
            % Since fprintf does not directly print % we have to replace
            % every occurance of it with %%
            sString = replace(sString, '%', '%%');
            
            fprintf(sSystemFile, sString);
            fprintf(sSystemFile, '\n');
            fprintf(sSystemFile, '\n');
        end
    end

    fprintf(sSystemFile, '      end\n');
    fprintf(sSystemFile, 'end\n');
    fprintf(sSystemFile, 'end');
    fclose(sSystemFile);
    
    % Apply smart indent on the file to make it easier to read
    file = matlab.desktop.editor.openDocument([sPath, filesep, sSystemName, '.m']);
    file.smartIndentContents
    file.save
    file.close
end
end