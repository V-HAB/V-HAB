function createSystemFiles(tVHAB_Objects, csPhases, csF2F, csSystems, sPath, sSystemLabel, tConvertIDs)
% This function loops through all systems and defines the necessary V-HAB
% code for them

for iSystem = 1:length(tVHAB_Objects.System)
    
    tCurrentSystem = tVHAB_Objects.System{iSystem};
    sSystemName = tools.normalizePath(tCurrentSystem.label);
    sSystemFile = fopen([sPath, filesep, sSystemName, '.m'], 'w');
    
    fprintf(sSystemFile, ['\n classdef ', sSystemName,' < vsys\n']);
    fprintf(sSystemFile, '\n properties\n');

    if ~isempty(tCurrentSystem.Human{1})
        tHuman = tCurrentSystem.Human{1};
        fprintf(sSystemFile, ['iCrewMembers = ',tHuman.iNumberOfCrew,';\n']);
    else
        fprintf(sSystemFile, 'iCrewMembers = 0;\n');
    end
    % If plants are used add the respective properties for them
    if ~isempty(tVHAB_Objects.Plants{1})
        if length(tVHAB_Objects.Plants) > 1
            error('Currently the GUI only allows the addition of one plant module, if you want to add more you have to adjust the properties in the code/ define the other plant cultures in the code')
        end
        tPlants = tVHAB_Objects.Plants{1};
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
        
        
        fprintf(sSystemFile, ['for iCrewMember = 1:', tHuman.iNumberOfCrew]);
        fprintf(sSystemFile,  '     txCrewPlaner.ctEvents = ctEvents(:, iCrewMember);');
        fprintf(sSystemFile,  '     txCrewPlaner.ctEvents = ctEvents(:, iCrewMember);');
        fprintf(sSystemFile,  '     txCrewPlaner.tMealTimes = tMealTimes;');
        fprintf(sSystemFile,  '     components.matter.DetailedHuman.Human(this, [''Human_'', num2str(iCrewMember)], txCrewPlaner, 60);');
        fprintf(sSystemFile,  '     clear txCrewPlaner;');
        fprintf(sSystemFile,  'end');
    end
    
    fprintf(sSystemFile, '\n');
    fprintf(sSystemFile, 'this.mfPlantArea = this.mfPlantArea .* this.iCrewMembers;\n');
            
    fprintf(sSystemFile, '\n');
    
    for iCCAA = 1:length(tCurrentSystem.CCAA)
        tCCAA = tCurrentSystem.CCAA{iCCAA};
        fprintf(sSystemFile, ['             components.matter.CCAA.CCAA(this, ''', tCCAA.label, ''', ', tCCAA.fTimeStep, ', ', tCCAA.fCoolantTemperature, ', [], ''',  tCCAA.sCDRA, ''');\n']);
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