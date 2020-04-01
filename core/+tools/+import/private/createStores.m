function tCurrentSystem = createStores(tCurrentSystem, csPhases, sSystemFile, tConvertIDs)
% Create Stores and Phases
fprintf(sSystemFile, '         %s Creating the Stores and Phases\n', '%%');
tCurrentSystem.csComponentIDs = cell(0);
for iStore = 1:length(tCurrentSystem.Stores)
    
    tStore = tCurrentSystem.Stores{iStore};
    fields = textscan(tStore.label,'%s','Delimiter','<');
    label = fields{1,1};
    label = label{1};
    sStoreName = tools.normalizePath(label);
    
    if isfield(tStore, 'fVolume') && ~isempty(tStore.fVolume)
        fVolume = tStore.fVolume;
    else
        error('In system %s in store %s the property fVolume was not defined in draw io!', sSystemName, sStoreName)
    end
    
    fprintf(sSystemFile, ['          matter.store(this,     ''', sStoreName,''',    ', fVolume, ');\n']);
    
    
    for iPhaseType = 1:length(csPhases)
        sPhase = (csPhases{iPhaseType});
        
        for iPhase = 1:length(tStore.(sPhase))
            
            tPhase = tStore.(sPhase){iPhase};
            
            sPhaseName = tools.normalizePath(tPhase.label);
            sSystemName = tCurrentSystem.label;
            
            if ~isempty(tPhase.fTemperature)
                fTemperature = tPhase.fTemperature;
            else
                error('In system %s in store %s in phase %s the property fTemperature was not defined in draw io!', sSystemName, sStoreName, sPhaseName)
            end
            
            if ~isempty(regexp(sPhase, 'Gas', 'once'))
            %% GAS
                if isfield(tPhase, 'fVolume') && ~isempty(tPhase.fVolume)
                    fPhaseVolume = tPhase.fVolume;
                else
                    error('In system %s in store %s in phase %s the property fVolume was not defined in draw io!', sSystemName, sStoreName, sPhaseName)
                end
                
                if isfield(tPhase, 'rRelHumidity') && ~isempty(tPhase.rRelHumidity)
                    rRelativeHumidity = tPhase.rRelHumidity;
                else
                    error('In system %s in store %s in phase %s the property rRelHumidity was not defined in draw io!', sSystemName, sStoreName, sPhaseName)
                end
                
                % For the partial pressure definition we want to allow the user
                % to set any partial pressure. This is achieved by allowing the
                % user to add "fPressureXX" Attributes to the system, the only
                % limitation is that XX must coincide with a valid entry from
                % the V-HAB matter table
                sPressureStruct = 'struct(';
                csAttributes = fieldnames(tPhase);
                for iAttribute = 1:length(csAttributes)
                    if ~isempty(regexp(csAttributes{iAttribute}, 'fPressure', 'once'))
                        sString = csAttributes{iAttribute};
                        sString = sString(10:end);
                        
                        sPressureStruct = [sPressureStruct, '''', sString, ''', ', num2str(tPhase.(csAttributes{iAttribute})), ', '];
                    end
                end
                sPressureStruct = sPressureStruct(1:end-2);
                sPressureStruct = [sPressureStruct, ')'];
                
                if ~isempty(regexp(sPhase, 'Boundary', 'once'))
                    fprintf(sSystemFile, ['          this.toStores.', sStoreName,'.createPhase(     ''gas'',    ''boundary'',	''', sPhaseName,''',	', fPhaseVolume,',	', sPressureStruct,',	', fTemperature, ',     ', rRelativeHumidity,');\n']);
                elseif ~isempty(regexp(sPhase, 'Flow', 'once'))
                    fprintf(sSystemFile, ['          this.toStores.', sStoreName,'.createPhase(     ''gas'',    ''flow'',       ''', sPhaseName,''',	', fPhaseVolume,',	', sPressureStruct,',	', fTemperature, ',     ', rRelativeHumidity,');\n']);
                else
                    fprintf(sSystemFile, ['          this.toStores.', sStoreName,'.createPhase(     ''gas'',                    ''', sPhaseName,''',	', fPhaseVolume,',	', sPressureStruct,',	', fTemperature, ',     ', rRelativeHumidity,');\n']);
                end
            elseif ~isempty(regexp(sPhase, 'Solid', 'once'))
            %% Solid
                % For the mass definition we want to allow the user to set
                % any mass. This is achieved by allowing the user to add
                % "fMassXX" Attributes to the system, the only limitation
                % is that XX must coincide with a valid entry from the
                % V-HAB matter table
                sMassStruct = 'struct(';
                csAttributes = fieldnames(tPhase);
                for iAttribute = 1:length(csAttributes)
                    if ~isempty(regexp(csAttributes{iAttribute}, 'fMass', 'once'))
                        sString = csAttributes{iAttribute};
                        sString = sString(6:end);
                        
                        sMassStruct = [sMassStruct, '''', sString, ''', ', num2str(tPhase.(csAttributes{iAttribute})), ', '];
                    end
                end
                sMassStruct = sMassStruct(1:end-2);
                sMassStruct = [sMassStruct, ')'];
                
                if ~isempty(regexp(sPhase, 'Boundary', 'once'))
                    fprintf(sSystemFile, ['          matter.phases.boundary.solid(  this.toStores.', sStoreName,',      ''', sPhaseName, ''',       ', sMassStruct,',       ', fTemperature,');\n']);
                elseif ~isempty(regexp(sPhase, 'Flow', 'once'))
                    fprintf(sSystemFile, ['          matter.phases.flow.solid(      this.toStores.', sStoreName,',      ''', sPhaseName, ''',       ', sMassStruct,',       ', fTemperature,');\n']);
                else
                    fprintf(sSystemFile, ['          matter.phases.solid(           this.toStores.', sStoreName,',      ''', sPhaseName, ''',       ', sMassStruct,',       ', fTemperature,');\n']);
                end
            elseif ~isempty(regexp(sPhase, 'Liquid', 'once'))
            %% Liquid
                if isfield(tPhase, 'fPressure') && ~isempty(tPhase.fPressure)
                    fPressure = tPhase.fPressure;
                else
                    error('In system %s in store %s in phase %s the property fPressure was not defined in draw io!', sSystemName, sStoreName, sPhaseName)
                end
                % For the mass definition we want to allow the user to set
                % any mass. This is achieved by allowing the user to add
                % "fMassXX" Attributes to the system, the only limitation
                % is that XX must coincide with a valid entry from the
                % V-HAB matter table
                sMassStruct = 'struct(';
                csAttributes = fieldnames(tPhase);
                for iAttribute = 1:length(csAttributes)
                    if ~isempty(regexp(csAttributes{iAttribute}, 'fMass', 'once'))
                        sString = csAttributes{iAttribute};
                        sString = sString(6:end);
                        
                        sMassStruct = [sMassStruct, '''', sString, ''', ', num2str(tPhase.(csAttributes{iAttribute})), ', '];
                    end
                end
                sMassStruct = sMassStruct(1:end-2);
                sMassStruct = [sMassStruct, ')'];
                
                if ~isempty(regexp(sPhase, 'Boundary', 'once'))
                    fprintf(sSystemFile, ['          matter.phases.boundary.liquid( this.toStores.', sStoreName,',      ''', sPhaseName, ''',       ', sMassStruct,',       ', fTemperature,',      ', fPressure,');\n']);
                elseif ~isempty(regexp(sPhase, 'Flow', 'once'))
                    fprintf(sSystemFile, ['          matter.phases.flow.liquid(     this.toStores.', sStoreName,',      ''', sPhaseName, ''',       ', sMassStruct,',       ', fTemperature,',      ', fPressure,');\n']);
                else
                    fprintf(sSystemFile, ['          matter.phases.liquid(          this.toStores.', sStoreName,',      ''', sPhaseName, ''',       ', sMassStruct,',       ', fTemperature,',      ', fPressure,');\n']);
                end
            elseif ~isempty(regexp(sPhase, 'Mixture', 'once'))
            %% Mixture
                if isfield(tPhase, 'sPhaseType') && ~isempty(tPhase.sPhaseType)
                    sPhaseType = tPhase.sPhaseType;
                else
                    error('In system %s in store %s in phase %s the property sPhaseType was not defined in draw io!', sSystemName, sStoreName, sPhaseName)
                end
                if isfield(tPhase, 'fPressure') && ~isempty(tPhase.fPressure)
                    fPressure = tPhase.fPressure;
                else
                    error('In system %s in store %s in phase %s the property fPressure was not defined in draw io!', sSystemName, sStoreName, sPhaseName)
                end
                % For the mass definition we want to allow the user to set
                % any mass. This is achieved by allowing the user to add
                % "fMassXX" Attributes to the system, the only limitation
                % is that XX must coincide with a valid entry from the
                % V-HAB matter table
                sMassStruct = 'struct(';
                csAttributes = fieldnames(tPhase);
                for iAttribute = 1:length(csAttributes)
                    if ~isempty(regexp(csAttributes{iAttribute}, 'fMass', 'once'))
                        sString = csAttributes{iAttribute};
                        sString = sString(6:end);
                        
                        sMassStruct = [sMassStruct, '''', sString, ''', ', num2str(tPhase.(csAttributes{iAttribute})), ', '];
                    end
                end
                sMassStruct = sMassStruct(1:end-2);
                sMassStruct = [sMassStruct, ')'];
                
                if ~isempty(regexp(sPhase, 'Boundary', 'once'))
                    fprintf(sSystemFile, ['          matter.phases.boundary.mixture(    this.toStores.', sStoreName,',      ''', sPhaseName, ''',       ''', sPhaseType,''',        ', sMassStruct,',       ', fTemperature,',      ', fPressure,');\n']);
                elseif ~isempty(regexp(sPhase, 'Flow', 'once'))
                    fprintf(sSystemFile, ['          matter.phases.flow.mixture(        this.toStores.', sStoreName,',      ''', sPhaseName, ''',       ''', sPhaseType,''',        ', sMassStruct,',       ', fTemperature,',      ', fPressure,');\n']);
                else
                    fprintf(sSystemFile, ['          matter.phases.mixture(             this.toStores.', sStoreName,',      ''', sPhaseName, ''',       ''', sPhaseType,''',        ', sMassStruct,',       ', fTemperature,',      ', fPressure,');\n']);
                end
            end
            
            tCurrentSystem.csComponentIDs{end+1} = tPhase.id;
            %% Create Manips
            for iManip = 1:length(tPhase.Manipulators)
                
                fprintf(sSystemFile, '\n');
                
                tManip = tPhase.Manipulators{iManip};
                
                if isempty(tManip.label)
                    tManip.label = [tPhase.label, '_Manipulator_', num2str(iManip)];
                end
                csFields = fieldnames(tManip);
                csStandardFields = {'id', 'label', 'sManipulatorType', 'sType', 'csToPlot', 'csToLog', 'ParentID'};
                bStandard = false;
                sInputs ='struct(';
                csFlowRates = cell.empty;
                iManipInputs = 0;
                for iField = 1:length(csFields)
                    for iStandardField = 1:length(csStandardFields)
                        if strcmp(csFields{iField}, csStandardFields{iStandardField})
                            bStandard = true;
                        end
                    end

                    if ~bStandard
                        if strcmp(tManip.sManipulatorType, 'components.matter.Manips.ManualManipulator')
                            
                            subfields = textscan(csFields{iField},'%s','Delimiter','_');
                            subfields = subfields{1};
                            
                            csFlowRates{end+1} = ['afFlowRates(this.oMT.tiN2I.', subfields{2},') = -', tManip.(csFields{iField}),';\n'];
                            csFlowRates{end+1} = ['afFlowRates(this.oMT.tiN2I.', subfields{4},') = ', tManip.(csFields{iField}),';\n'];
                        else
                            sInputs = [sInputs, '''', csFields{iField}, ''', ', tManip.csFields{iField}, ', '];
                            iManipInputs = iManipInputs + 1;
                        end
                    end
                end
                sInputs = sInputs(1:end-3);
                sInputs = [sInputs, ')'];
                
                if strcmp(tManip.sManipulatorType, 'components.matter.Manips.ManualManipulator')
                    
                    fprintf(sSystemFile, ['oManip = ', tManip.sManipulatorType, '(this, ''', tManip.label, ''', this.toStores.', tStore.label,'.toPhases.', tPhase.label, ');\n']);
                    
                    fprintf(sSystemFile,  'afFlowRates = zeros(1, this.oMT.iSubstances);\n');
                    for iFlow = 1:length(csFlowRates)
                        fprintf(sSystemFile, csFlowRates{iFlow});
                    end
                    fprintf(sSystemFile,  'oManip.setFlowRate(afFlowRates);\n\n');
                else
                    if iManipInputs > 0
                        fprintf(sSystemFile,  [tManip.sManipulatorType, '(this, ''', tManip.label, ''', this.toStores.', tStore.label,'.toPhases.', tPhase.label, ', ', sInputs, ');\n']);
                    else
                        fprintf(sSystemFile,  [tManip.sManipulatorType, '(this, ''', tManip.label, ''', this.toStores.', tStore.label,'.toPhases.', tPhase.label, ');\n']);
                    end
                end
            end
            
            %% Create heatsources

            for iHeatSource = 1:length(tPhase.HeatSource)
                tHeatSource = tPhase.HeatSource{iHeatSource};
                
                fprintf(sSystemFile, '\n');
                
                if isempty(tHeatSource.label)
                    tHeatSource.label = [tPhase.label, '_HeatSource_', num2str(iHeatSource)];
                end
                
                if strcmp(tHeatSource.sHeatSourceType, 'components.thermal.heatsources.ConstantTemperature')
                    fprintf(sSystemFile, ['oHeatSource = ', tHeatSource.sHeatSourceType, '(''', tHeatSource.label,''');\n']);
                else
                    fprintf(sSystemFile, ['oHeatSource = ', tHeatSource.sHeatSourceType, '(''', tHeatSource.label,''', ', tHeatSource.fHeatFlow,');\n']);
                end
                fprintf(sSystemFile, ['this.toStores.', tStore.label,'.toPhases.', tPhase.label,'.oCapacity.addHeatSource(oHeatSource);\n']);
            end
        end
    end
    
    %% Create p2Ps
    for iP2P = 1:length(tStore.P2Ps)
        tP2P = tStore.P2Ps{iP2P};
        
        fprintf(sSystemFile, '\n');
        
        if isempty(tP2P.label)
            tP2P.label = [tStore.label, '_P2P_', num2str(iP2P)];
        end
        
        sSourcePhase = tConvertIDs.tIDtoLabel.(tP2P.SourceID);
        
        if ~isempty(regexpi(tConvertIDs.tIDtoType.(tP2P.SourceID), 'Gas'))
            sPhaseTypeSource = 'gas';
        elseif ~isempty(regexpi(tConvertIDs.tIDtoType.(tP2P.SourceID), 'Liquid'))
            sPhaseTypeSource = 'liquid';
        elseif ~isempty(regexpi(tConvertIDs.tIDtoType.(tP2P.SourceID), 'Solid'))
            sPhaseTypeSource = 'solid';
        elseif ~isempty(regexpi(tConvertIDs.tIDtoType.(tP2P.SourceID), 'Mixture'))
            sPhaseTypeSource = 'mixture';
        end
        sSourceExme = [tP2P.label,'_Out'''];
        fprintf(sSystemFile,  ['matter.procs.exmes.', sPhaseTypeSource,'(this.toStores.', tStore.label, '.toPhases.', sSourcePhase,', ''', sSourceExme, ');\n']);
        
        sTargetPhase = tConvertIDs.tIDtoLabel.(tP2P.TargetID);
        if ~isempty(regexpi(tConvertIDs.tIDtoType.(tP2P.TargetID), 'Gas'))
            sPhaseTypeTarget = 'gas';
        elseif ~isempty(regexpi(tConvertIDs.tIDtoType.(tP2P.TargetID), 'Liquid'))
            sPhaseTypeTarget = 'liquid';
        elseif ~isempty(regexpi(tConvertIDs.tIDtoType.(tP2P.TargetID), 'Solid'))
            sPhaseTypeTarget = 'solid';
        elseif ~isempty(regexpi(tConvertIDs.tIDtoType.(tP2P.TargetID), 'Mixture'))
            sPhaseTypeTarget = 'mixture';
        end
        sTargetExme = [tP2P.label,'_In'''];
        fprintf(sSystemFile,  ['matter.procs.exmes.', sPhaseTypeTarget,'(this.toStores.', tStore.label, '.toPhases.', sTargetPhase,', ''', sTargetExme, ');\n']);
        
        
        sSource = [sSourcePhase, '.', sSourceExme];
        sTarget = [sTargetPhase, '.', sTargetExme];
        
        if strcmp(tP2P.sP2P_Type, 'components.matter.P2Ps.ManualP2P')
            fprintf(sSystemFile,  ['oP2P = ', tP2P.sP2P_Type, '(this.toStores.', tStore.label, ', ''', tP2P.label, ''', ''', sSource, ', ''', sTarget, ');\n']);
            
            csFields = fieldnames(tP2P);
            csStandardFields = {'id', 'label', 'sP2P_Type', 'sType', 'csToPlot', 'csToLog', 'ParentID', 'SourceID', 'TargetID'};
            
            csFlowRates = cell.empty;
            for iField = 1:length(csFields)
                bStandard = false;
                for iStandardField = 1:length(csStandardFields)
                    if strcmp(csFields{iField}, csStandardFields{iStandardField})
                        bStandard = true;
                    end
                end
                
                if ~bStandard
                    
                    sSubstance = csFields{iField}(10:end);
                    
                    csFlowRates{end+1} = ['afFlowRates(this.oMT.tiN2I.', sSubstance,') = ', tP2P.(csFields{iField}),';\n'];
                end
            end
            
            fprintf(sSystemFile,  'afFlowRates = zeros(1, this.oMT.iSubstances);\n');
            for iFlow = 1:length(csFlowRates)
                fprintf(sSystemFile, csFlowRates{iFlow});
            end
            fprintf(sSystemFile,  'oP2P.setFlowRate(afFlowRates);\n\n');
            
        elseif strcmp(tP2P.sP2P_Type, 'components.matter.P2Ps.ConstantMassP2P')
            fprintf(sSystemFile,  [tP2P.sP2P_Type, '(this.toStores.', tStore.label, ', ''', tP2P.label, ''', ''', sSource, ', ''', sTarget, ', {''', tP2P.sSubstance, '''}, 1);\n']);
            
        else
            fprintf(sSystemFile,  [tP2P.sP2P_Type, '(this.toStores.', tStore.label, ', ''', tP2P.label, ''', ''', sSource, ', ''', sTarget, ');\n']);
        end
        
    end
    
    fprintf(sSystemFile, '\n');
end

%% Add Food stores
for iFoodStore = 1:length(tCurrentSystem.FoodStores)
    tFoodStore = tCurrentSystem.FoodStores{iFoodStore};
    
    csAttributes = fieldnames(tFoodStore);
    sMassStruct = 'struct(';
    for iAttribute = 1:length(csAttributes)
        if ~isempty(regexp(csAttributes{iAttribute}, 'fMass', 'once'))
            sString = csAttributes{iAttribute};
            sString = sString(6:end);

            sMassStruct = [sMassStruct, '''', sString, ''', ', num2str(tFoodStore.(csAttributes{iAttribute})), ', '];
        end
    end
    sMassStruct = sMassStruct(1:end-2);
    sMassStruct = [sMassStruct, ')'];
    
    fprintf(sSystemFile, ['components.matter.FoodStore(this, ''', tFoodStore.label ''', ', tFoodStore.fVolume,', ', sMassStruct, ');\n']);
end
end