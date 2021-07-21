function createSetupFile(tVHAB_Objects, sPath, sSystemLabel, sRootName, csPhases, csF2F, oMT, tSystemIDtoLabel, bHumanModel)
%% Create Setup File
sSetupFileID = fopen([sPath, filesep, 'setup.m'], 'w');

fprintf(sSetupFileID, '\n classdef setup < simulation.infrastructure\n \n properties\n end\n \n methods\n\n');
fprintf(sSetupFileID, '    function  this = setup(ptConfigParams, tSolverParams) \n');

fprintf(sSetupFileID, '         %s Creating the monitors struct\n', '%');
fprintf(sSetupFileID, '        ttMonitorConfig = struct();\n\n');

if isfield(tVHAB_Objects.Setup{1}, 'DumpLogFiles')
    fprintf(sSetupFileID, ['        ttMonitorConfig.oLogger.cParams = {', tVHAB_Objects.Setup{1}.DumpLogFiles,'};\n\n']);
end
if isfield(tVHAB_Objects.Setup{1}, 'TimeStepObserver')
    if strcmp(tVHAB_Objects.Setup{1}.TimeStepObserver, 'true')
        fprintf(sSetupFileID, '        ttMonitorConfig.oTimeStepObserver.sClass = ''simulation.monitors.timestepObserver'';\n');
        fprintf(sSetupFileID, '        ttMonitorConfig.oTimeStepObserver.cParams = { 0 };\n\n');
    end
end
if isfield(tVHAB_Objects.Setup{1}, 'MassBalanceObserver')
    if strcmp(tVHAB_Objects.Setup{1}.MassBalanceObserver, 'true')
        fprintf(sSetupFileID, '        ttMonitorConfig.oMassBalanceObserver.sClass = ''simulation.monitors.massbalanceObserver'';\n');
        fprintf(sSetupFileID, '        fAccuracy = 1e-8;\n');
        fprintf(sSetupFileID, '        fMaxMassBalanceDifference = inf;\n');
        fprintf(sSetupFileID, '        bSetBreakPoints = false;\n');
        fprintf(sSetupFileID, '        ttMonitorConfig.oMassBalanceObserver.cParams = { fAccuracy, fMaxMassBalanceDifference, bSetBreakPoints };\n\n');
    end
end
fprintf(sSetupFileID, '\n');
fprintf(sSetupFileID, [' this@simulation.infrastructure(''', sRootName,  ''', ptConfigParams, tSolverParams, ttMonitorConfig);\n']);

fprintf(sSetupFileID, '         %s Defining Compound Masses for the Simulation\n', '%');
fprintf(sSetupFileID, '         trBaseCompositionUrine.H2O      = 0.9644;\n');
fprintf(sSetupFileID, '         trBaseCompositionUrine.CH4N2O = 0.0356;\n');
fprintf(sSetupFileID, '         this.oSimulationContainer.oMT.defineCompoundMass(this, ''Urine'', trBaseCompositionUrine);\n');
fprintf(sSetupFileID, '         trBaseCompositionFeces.H2O          = 0.7576;\n');
fprintf(sSetupFileID, '         trBaseCompositionFeces.DietaryFiber  = 0.2424;\n');
fprintf(sSetupFileID, '         this.oSimulationContainer.oMT.defineCompoundMass(this, ''Feces'', trBaseCompositionFeces);\n');
fprintf(sSetupFileID, '         trBaseCompositionBrine.H2O         	= 0.8;\n');
fprintf(sSetupFileID, '         trBaseCompositionBrine.C2H6O2N2     = 0.2;\n');
fprintf(sSetupFileID, '         this.oSimulationContainer.oMT.defineCompoundMass(this, ''Brine'', trBaseCompositionBrine);\n');
fprintf(sSetupFileID, '         trBaseCompositionConcentratedBrine.H2O         	= 0.44;\n');
fprintf(sSetupFileID, '         trBaseCompositionConcentratedBrine.C2H6O2N2     = 0.56;\n');
fprintf(sSetupFileID, '         this.oSimulationContainer.oMT.defineCompoundMass(this, ''ConcentratedBrine'', trBaseCompositionConcentratedBrine);\n');

fprintf(sSetupFileID, '         %s Creating the root object\n', '%');
fprintf(sSetupFileID, ['        DrawIoImport.', sSystemLabel, '.systems.', sRootName, '(this.oSimulationContainer, ''',  sRootName,''');\n\n']);

fprintf(sSetupFileID, ['        this.fSimTime = ', tVHAB_Objects.Setup{1}.fSimTime, ';\n']);
fprintf(sSetupFileID, '        this.bUseTime = true;\n');

fprintf(sSetupFileID, '     end\n\n');

fprintf(sSetupFileID, '     function configureMonitors(this)\n');
fprintf(sSetupFileID, '         oLogger = this.toMonitors.oLogger;\n\n');

% For logging we need the full depth hierarchical path of the current
% system. How can we get this? --> Adapt and revise hierarchical structuring
% function and then store the path for each system in the system
[tVHAB_Objects, ~] = createHierarchy(tVHAB_Objects, tSystemIDtoLabel);

for iSystem = 1:length(tVHAB_Objects.System)
    tSystem = tVHAB_Objects.System{iSystem};
    % check log and plot for system
    sSystemPath = ['         oLogger.addValue(''', tSystem.sFullPath];
    
    tVHAB_Objects.System{iSystem}.csLoggedNames = cell(0);
    csToLog = {tSystem.csToPlot{:}, tSystem.csToLog{:}};%#ok
    for iLog = 1:length(csToLog)
        sLogValueName = [tSystem.label, ' ', csToLog{iLog}];
        tVHAB_Objects.System{iSystem}.csLoggedNames{end+1} = sLogValueName;
        fprintf(sSetupFileID, [sSystemPath, ''', ''', csToLog{iLog},', ''-'', ''', sLogValueName,''');\n']);
    end
    
    for iStore = 1:length(tSystem.Stores)
        tStore = tSystem.Stores{iStore};
        
        tVHAB_Objects.System{iSystem}.Stores{iStore}.csLoggedNames = cell(0);
        csToLog = {tStore.csToPlot{:}, tStore.csToLog{:}};%#ok
        for iLog = 1:length(tStore.csToLog)
            sLogValueName = [tSystem.label, ' ', tStore.label, ' ', csToLog{iLog}];
            tVHAB_Objects.System{iSystem}.Stores{iStore}.csLoggedNames{end+1} = sLogValueName;
            fprintf(sSetupFileID, [sSystemPath, '.toStores.', tStore.label,''', ''', csToLog{iLog},''', ''-'', ''', sLogValueName,''');\n']);
        end
        
        % check store
        for iPhaseType = 1:length(csPhases)
            sPhase = (csPhases{iPhaseType});
            for iPhase = 1:length(tStore.(sPhase))
                % check phase
                tPhase = tStore.(sPhase){iPhase};
                
                tVHAB_Objects.System{iSystem}.Stores{iStore}.(sPhase){iPhase}.csLoggedNames = cell(0);
                csToLog = {tPhase.csToPlot{:}, tPhase.csToLog{:}};%#ok
                for iLog = 1:length(csToLog)
                    if ~isempty(regexp(csToLog{iLog}, 'fPressure', 'once')) && length(csToLog{iLog}) > 9
                        sSubstance = csToLog{iLog}(10:end);
                        
                        % We have to check if the substance was defined
                        % by name and not by shorthand
                        if ~isfield(oMT.tiN2I, sSubstance)
                            for iSubstance = 1:oMT.iSubstances
                                if strcmp(oMT.ttxMatter.(oMT.csSubstances{iSubstance}).sName, sSubstance)
                                    sSubstance = oMT.csSubstances{iSubstance};
                                end
                            end
                        end
                        
                        sLogValue = ['afPP(this.oMT.tiN2I.', sSubstance,')'];
                        sLogValueName = [tSystem.label, ' ', tStore.label, ' ', tPhase.label, ' Partial Pressure ', csToLog{iLog}(10:end)];
                        sUnit = 'Pa';
                        
                    elseif ~isempty(regexp(csToLog{iLog}, 'fTemperature', 'once'))
                        sLogValue = csToLog{iLog};
                        sLogValueName = [tSystem.label, ' ', tStore.label, ' ', tPhase.label, ' ', 'Temperature'];
                        sUnit = 'K';
                        
                    elseif ~isempty(regexp(csToLog{iLog}, 'fMass', 'once'))
                        if length(csToLog{iLog}) > 5
                            sSubstance = csToLog{iLog}(6:end);
                            % We have to check if the substance was defined
                            % by name and not by shorthand
                            if ~isfield(oMT.tiN2I, sSubstance)
                                for iSubstance = 1:oMT.iSubstances
                                    if strcmp(oMT.ttxMatter.(oMT.csSubstances{iSubstance}).sName, sSubstance)
                                        sSubstance = oMT.csSubstances{iSubstance};
                                    end
                                end
                            end
                            sLogValue = ['afMass(this.oMT.tiN2I.', sSubstance,')'];
                            sLogValueName = [tSystem.label, ' ', tStore.label, ' ', tPhase.label, ' Partial Mass ', csToLog{iLog}(6:end)];
                            sUnit = 'kg';
                        end
                        
                    elseif ~isempty(regexp(csToLog{iLog}, 'rRelHumidity', 'once'))
                        sLogValue = csToLog{iLog};
                        sLogValueName = [tSystem.label, ' ', tStore.label, ' ', tPhase.label, ' Relative Humidity'];
                        sUnit = '-';
                        
                    else
                        sLogValue = csToLog{iLog};
                        sLogValueName = [tSystem.label, ' ', tStore.label, ' ', tPhase.label, ' ', csToLog{iLog}];
                        sUnit = '-';
                    end
                    tVHAB_Objects.System{iSystem}.Stores{iStore}.(sPhase){iPhase}.csLoggedNames{iLog} = sLogValueName;
                    fprintf(sSetupFileID, [sSystemPath, '.toStores.', tStore.label,'.toPhases.', tPhase.label, ''', ''', sLogValue,''', ''', sUnit,''' ,''', sLogValueName,''');\n']);
                end
            end
        end
        
        % TO DO: Log/plot P2Ps
    end
    
    
    for iFoodStore = 1:length(tVHAB_Objects.System{iSystem}.FoodStores)
        tVHAB_Objects.System{iSystem}.FoodStores{iFoodStore}.csLoggedNames = cell(0);
        tFoodStore = tVHAB_Objects.System{iSystem}.FoodStores{iFoodStore};
        
        csToLog = {tFoodStore.csToPlot{:}, tFoodStore.csToLog{:}};%#ok
        for iLog = 1:length(csToLog)
            
            if ~isempty(regexp(csToLog{iLog}, 'fMass', 'once'))
                if length(csToLog{iLog}) > 5
                    sSubstance = csToLog{iLog}(6:end);
                    % We have to check if the substance was defined
                    % by name and not by shorthand
                    if ~isfield(oMT.tiN2I, sSubstance)
                        for iSubstance = 1:oMT.iSubstances
                            if strcmp(oMT.ttxMatter.(oMT.csSubstances{iSubstance}).sName, sSubstance)
                                sSubstance = oMT.csSubstances{iSubstance};
                            end
                        end
                    end
                    sLogValue = ['afMass(this.oMT.tiN2I.', sSubstance,')'];
                    sLogValueName = [tSystem.label, ' ', tFoodStore.label, ' Partial Mass ', csToLog{iLog}(6:end)];
                else
                    sLogValue = 'fMass';
                    sLogValueName = [tSystem.label, ' ', tFoodStore.label, ' Mass'];
                end
                sUnit = 'kg';
            else
                sLogValue = csToLog{iLog};
                sLogValueName = [tSystem.label, ' ', tFoodStore.label, ' ', csToLog{iLog}];
                sUnit = '-';
            end
            
            tVHAB_Objects.System{iSystem}.FoodStores{iFoodStore}.csLoggedNames{end+1} = sLogValueName;
            
            fprintf(sSetupFileID, [sSystemPath, '.toStores.', tFoodStore.label,'.toPhases.Food'', ''', sLogValue,''', ''', sUnit,''' ,''', sLogValueName,''');\n']);
        end
    end
    
    for iBranch = 1:length(tVHAB_Objects.System{iSystem}.cVHABBranches)
        tVHAB_Objects.System{iSystem}.cVHABBranches{iBranch}.csLoggedNames = cell(0);
        tBranch = tVHAB_Objects.System{iSystem}.cVHABBranches{iBranch};
        
        csToLog = {tBranch.csToPlot{:}, tBranch.csToLog{:}};%#ok
        for iLog = 1:length(csToLog)
            sUnit = '-';
            sAlternativeLogName = '';
            if ~isempty(regexp(csToLog{iLog}, 'fFlowRate', 'once'))
                sUnit = 'kg/s';
                % Check if the user wanted to plot a partial mass flow rate
                if length(csToLog{iLog}) > 9
                    sSubstance = csToLog{iLog}(10:end);
                    csToLog{iLog} = ['this.fFlowRate * this.aoFlows(1).arPartialMass(this.oMT.tiN2I.', sSubstance, ')'];
                    sAlternativeLogName = ['Partial Mass Flow Rate ', sSubstance];
                end
            end
            
            if ~isempty(tBranch.sCustomName)
                if ~isempty(sAlternativeLogName)
                    sLogValueName = sAlternativeLogName;
                else
                    sLogValueName = [tBranch.sCustomName, ' ', csToLog{iLog}];
                end
                tVHAB_Objects.System{iSystem}.cVHABBranches{iBranch}.csLoggedNames{end+1} = sLogValueName;
                fprintf(sSetupFileID, [sSystemPath, '.toBranches.', tBranch.sCustomName, ''', ''', csToLog{iLog},''', ''', sUnit,''', ''', sLogValueName,''');\n']);
            else
                
                if ~isempty(sAlternativeLogName)
                    sLogValueName = sAlternativeLogName;
                else
                    sLogValueName = ['Branch ', num2str(iBranch), ' ', csToLog{iLog}];
                end
                tVHAB_Objects.System{iSystem}.cVHABBranches{iBranch}.csLoggedNames{end+1} = sLogValueName;
                fprintf(sSetupFileID, [sSystemPath, '.aoBranches(', num2str(iBranch), ')'', ''', csToLog{iLog},''', ''', sUnit,''', ''', sLogValueName,''');\n']);
                
            end
        end
        
        % TO DO: log plot F2Fs
    end
end
fprintf(sSetupFileID, '     end\n\n');

fprintf(sSetupFileID, '     function plot(this, varargin)\n');
fprintf(sSetupFileID, '         close all\n');
fprintf(sSetupFileID, '         oPlotter = plot@simulation.infrastructure(this);\n');
% TO DO Add plotting
for iSystem = 1:length(tVHAB_Objects.System)
    tSystem = tVHAB_Objects.System{iSystem};
    % check log and plot for system
    for iPlot = 1:length(tSystem.csToPlot)
        fprintf(sSetupFileID, ['         coPlot = oPlotter.definePlot({''"', tSystem.csLoggedNames{iPlot}, '"''}, ''', tSystem.csLoggedNames{iPlot}, ''');\n']);
        fprintf(sSetupFileID, ['         oPlotter.defineFigure(coPlot,  ''', tSystem.csLoggedNames{iPlot},''');\n']);
    end
    
    tPlots = struct();
    for iStore = 1:length(tSystem.Stores)
        tStore = tSystem.Stores{iStore};
        
        for iPlot = 1:length(tStore.csToPlot)
            fprintf(sSetupFileID, ['         coPlot = oPlotter.definePlot({''"', tStore.csLoggedNames{iPlot}, '"''}, ''', tStore.csLoggedNames{iPlot}, ''');\n']);
            fprintf(sSetupFileID, ['         oPlotter.defineFigure(coPlot,  ''', tStore.csLoggedNames{iPlot},''');\n']);
        end
        
        % check store
        for iPhaseType = 1:length(csPhases)
            sPhase = (csPhases{iPhaseType});
            for iPhase = 1:length(tStore.(sPhase))
                % check phase
                tPhase = tStore.(sPhase){iPhase};
                csToPlot = tPhase.csToPlot;
                for iPlot = 1:length(csToPlot)
                    if ~isempty(regexp(csToPlot{iPlot}, 'fPressure', 'once')) && length(csToPlot{iPlot}) > 9
                        
                        if ~isfield(tPlots, 'sPressures')
                            tPlots.sPressures           = '{''"';
                        end
                        tPlots.sPressures = [tPlots.sPressures, tPhase.csLoggedNames{iPlot}, '"'', ''"'];
                        
                    elseif ~isempty(regexp(csToPlot{iPlot}, 'fTemperature', 'once'))
                        
                        if ~isfield(tPlots, 'sTemperatures')
                            tPlots.sTemperatures           = '{''"';
                        end
                        tPlots.sTemperatures = [tPlots.sTemperatures, tPhase.csLoggedNames{iPlot}, '"'', ''"'];
                        
                    elseif ~isempty(regexp(csToPlot{iPlot}, 'fMass', 'once'))
                        if length(csToPlot{iPlot}) > 5
                            if ~isfield(tPlots, 'sMass')
                                tPlots.sMass           = '{''"';
                            end
                            tPlots.sMass = [tPlots.sMass, tPhase.csLoggedNames{iPlot}, '"'', ''"'];
                        end
                        
                    elseif strcmp(csToPlot{iPlot}, 'rRelHumidity')
                        
                        if ~isfield(tPlots, 'sRelativeHumidity')
                            tPlots.sRelativeHumidity           = '{''"';
                        end
                        tPlots.sRelativeHumidity = [tPlots.sRelativeHumidity, tPhase.csLoggedNames{iPlot}, '"'', ''"'];
                        
                    else
                        if ~isfield(tPlots, (tools.normalizePath(csToPlot{iPlot})))
                            tPlots.(tools.normalizePath(csToPlot{iPlot}))    = '{''"';
                        end
                        tPlots.(tools.normalizePath(csToPlot{iPlot})) = [tPlots.(tools.normalizePath(csToPlot{iPlot})), tPhase.csLoggedNames{iPlot}, '"'', ''"'];
                    end
                    
                end
            end
        end
    end
    
    for iFoodStore = 1:length(tVHAB_Objects.System{iSystem}.FoodStores)
        tFoodStore = tVHAB_Objects.System{iSystem}.FoodStores{iFoodStore};
        
        csToPlot = tFoodStore.csToPlot;
        for iPlot = 1:length(csToPlot)
            if ~isempty(regexp(csToPlot{iPlot}, 'fMass', 'once')) || strcmp(csToPlot{iPlot}, 'fMass')
                if length(csToPlot{iPlot}) >= 5
                    if ~isfield(tPlots, 'sMass')
                        tPlots.sMass           = '{''"';
                    end
                    tPlots.sMass = [tPlots.sMass, tFoodStore.csLoggedNames{iPlot}, '"'', ''"'];
                end
            else
                
                if ~isfield(tPlots, (tools.normalizePath(csToPlot{iPlot})))
                    tPlots.(tools.normalizePath(csToPlot{iPlot}))    = '{''"';
                end
                tPlots.(tools.normalizePath(csToPlot{iPlot})) = [tPlots.(tools.normalizePath(csToPlot{iPlot})), tFoodStore.csLoggedNames{iPlot}, '"'', ''"'];
            end
        end
    end
    
    for iBranch = 1:length(tVHAB_Objects.System{iSystem}.cVHABBranches)
        tBranch = tVHAB_Objects.System{iSystem}.cVHABBranches{iBranch};
        
        csToPlot = tBranch.csToPlot;
        for iPlot = 1:length(csToPlot)
            if ~isfield(tPlots, (tools.normalizePath(csToPlot{iPlot})))
                tPlots.(tools.normalizePath(csToPlot{iPlot}))    = '{''"';
            end
            tPlots.(tools.normalizePath(csToPlot{iPlot})) = [tPlots.(tools.normalizePath(csToPlot{iPlot})), tBranch.csLoggedNames{iPlot}, '"'', ''"'];
        end
    end
    
    %% do the plotting
    csPlots = fieldnames(tPlots);
    for iPlot = 1:length(csPlots)
        sPlot = csPlots{iPlot};
        tPlots.(sPlot) = tPlots.(sPlot)(1:end-4);
        tPlots.(sPlot) = [tPlots.(sPlot), '}'];
    end
    
    if isfield(tPlots, 'sPressures')
        fprintf(sSetupFileID, ['         coPlot{1,1} = oPlotter.definePlot(', tPlots.sPressures,', ''',  tSystem.label, ' Pressures'');\n']);
        tPlots = rmfield(tPlots, 'sPressures');
    end
    if isfield(tPlots, 'sTemperatures')
        fprintf(sSetupFileID, ['         coPlot{1,2} = oPlotter.definePlot(', tPlots.sTemperatures,', ''',  tSystem.label, ' Temperatures'');\n']);
        tPlots = rmfield(tPlots, 'sTemperatures');
    end
    if isfield(tPlots, 'sMass')
        fprintf(sSetupFileID, ['         coPlot{2,1} = oPlotter.definePlot(', tPlots.sMass,', ''',  tSystem.label, ' Masses'');\n']);
        tPlots = rmfield(tPlots, 'sMass');
    end
    if isfield(tPlots, 'sRelativeHumidity')
        fprintf(sSetupFileID, ['         coPlot{2,2} = oPlotter.definePlot(', tPlots.sRelativeHumidity,', ''',  tSystem.label, ' Relative Humidity'');\n']);
        tPlots = rmfield(tPlots, 'sRelativeHumidity');
    end
    fprintf(sSetupFileID, ['         oPlotter.defineFigure(coPlot,  ''', tSystem.label, ' Phase Parameters'');\n']);
    
    
    csPlots = fieldnames(tPlots);
    for iPlot = 1:length(csPlots)
        fprintf(sSetupFileID, '         coPlot = cell(0);\n');
        fprintf(sSetupFileID, ['         coPlot{1,1} = oPlotter.definePlot(', tPlots.(csPlots{iPlot}),', ''',  tSystem.label, ' ', csPlots{iPlot}, ''');\n']);
        fprintf(sSetupFileID, ['         oPlotter.defineFigure(coPlot,  ''', tSystem.label, ' ', csPlots{iPlot}, ''');\n']);
    end
    
end
fprintf(sSetupFileID, '         oPlotter.plot();\n');
fprintf(sSetupFileID, '     end\n\n');

fprintf(sSetupFileID, 'end\n end\n');

fclose(sSetupFileID);

file = matlab.desktop.editor.openDocument([sPath, filesep, 'setup.m']);
file.smartIndentContents
file.save
file.close
end