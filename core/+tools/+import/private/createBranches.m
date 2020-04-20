function tCurrentSystem = createBranches(tCurrentSystem, tVHAB_Objects, csSystems, sSystemFile)
%% Create Branches
% This functions creates all branches and defines the necessary interfaces
% between systems for the branches

% We now check what branches connect to phases in the current system.
% This also includes interface branches between the different systems
% TO DO: probably connecting two subsystems directly will not work in
% the initial implementation

fprintf(sSystemFile, '         %s Creating the branches\n', '%%');
for iBranch = 1:length(tCurrentSystem.csBranches)
    sBranch = tCurrentSystem.csBranches{iBranch};
    
    fprintf(sSystemFile, [sBranch, '\n']);
end
fprintf(sSystemFile, '\n');


%% Create Interfaces
tcsParentSideInterfaces = struct();
csChildSideInterfaces = cell(0);
for iInterface = 1:length(tCurrentSystem.csInterfaces)
    if strcmp(tCurrentSystem.csInterfaceIDs{iInterface}{2} ,tCurrentSystem.id)
        % we are the right side and therefore the parent
        for iChild = 1:length(tVHAB_Objects.System)
            if strcmp(tCurrentSystem.csInterfaceIDs{iInterface}{1}, tVHAB_Objects.System{iChild}.id)
                
                if ~isfield(tcsParentSideInterfaces, tVHAB_Objects.System{iChild}.label)
                    tcsParentSideInterfaces.(tVHAB_Objects.System{iChild}.label) = cell(0);
                end
                tcsParentSideInterfaces.(tVHAB_Objects.System{iChild}.label){end+1} = tCurrentSystem.csInterfaces{iInterface}{1};
                break
            end
        end
        
    elseif  strcmp(tCurrentSystem.csInterfaceIDs{iInterface}{1} ,tCurrentSystem.id)
        % we are the left side and therefore the child system
        csChildSideInterfaces{end+1} = tCurrentSystem.csInterfaces{iInterface}{2};
    else
        error('Something went wrong during interface definition')
    end
end

csChildren = fieldnames(tcsParentSideInterfaces);
for iChild = 1:length(csChildren)
    if ~isempty(tcsParentSideInterfaces.(csChildren{iChild}))
        
        sSetInterfaces = ['this.toChildren.', csChildren{iChild},'.setIfFlows('];
        csIFs = tcsParentSideInterfaces.(csChildren{iChild});
        for iParentIF = 1:length(csIFs)
            sSetInterfaces = [sSetInterfaces, csIFs{iParentIF}, ', '];
        end
        sSetInterfaces = sSetInterfaces(1:end-2);
        sSetInterfaces = [sSetInterfaces, ');\n'];
        
        fprintf(sSystemFile, sSetInterfaces);
    end
end


% Definition of the interfaces with the names from the xml drawing but the
% order of the subsystem IF definition function
tInterfaces.Human = {'Air_Out', 'Air_In', 'Water_In', 'Food_In', 'Feces_Out', 'Urine_Out'};
tInterfaces.CDRA  = {'Air_In', 'Air_Out', 'CO2_Out'};
tInterfaces.OGA  =  {'Water_In', 'O2_Out', 'H2_Out'};
tInterfaces.SCRA  = {'H2_In', 'CO2_In', 'Gas_Out', 'Condensate_Out', 'Coolant_In', 'Coolant_Out'};
tInterfaces.Plant = {'Air_In', 'Air_Out', 'Water_In', 'Nutrient_In', 'Biomass_Out'};
tInterfaces.HFC   = {'Air_In', 'Air_Out'};
tInterfaces.Electrolyzer = {'H2_Out', 'O2_Out', 'Water_In', 'Coolant_Out', 'Coolant_In'};
tInterfaces.FuelCell     = {'H2_In',  'H2_Out', 'O2_In', 'O2_Out', 'Coolant_In', 'Coolant_Out', 'Water_Out'};

for iSubsystemType = 1:length(csSystems)
    sSubsystemType = csSystems{iSubsystemType};
    for iSubsystem = 1:length(tCurrentSystem.(sSubsystemType))
        tSubsystem = tCurrentSystem.(csSystems{iSubsystemType}){iSubsystem};
        
        % The CCAA has a variable number of outputs
        if strcmp(sSubsystemType, 'CCAA')
            if isempty(tSubsystem.sCDRA)
                tInterfaces.CCAA = {'Air_In', 'CHX_Air_Out', 'Bypass_Air_Out', 'Condensate_Out', 'Coolant_In', 'Coolant_Out'};
            else
                
                tInterfaces.CCAA = {'Air_In', 'CHX_Air_Out', 'Bypass_Air_Out', 'Condensate_Out', 'Coolant_In', 'Coolant_Out', 'CDRA_Air_Out'};
            end
        end
        
        csInterface = cell.empty();
        if strcmp(sSubsystemType, 'Subsystem')
            if strcmp(tSubsystem.sSubsystemPath, 'components.matter.PlantModuleV2.PlantCulture')
                csInterfaces = tInterfaces.Plant;
            elseif strcmp(tSubsystem.sSubsystemPath, 'hojo.ILCO2.subsystems.HFC')
                csInterfaces = tInterfaces.HFC;
            elseif strcmp(tSubsystem.sSubsystemPath, 'components.matter.Electrolyzer.Electrolyzer')
                csInterfaces = tInterfaces.Electrolyzer;
            elseif strcmp(tSubsystem.sSubsystemPath, 'components.matter.FuelCell.FuelCell')
                csInterfaces = tInterfaces.FuelCell;
                
            else
                error('unknown subsystem type was used')
            end
        else
            csInterfaces = tInterfaces.(sSubsystemType);
        end
        for iInterface = 1:length(csInterfaces)
            
            sInterface = csInterfaces{iInterface};
            csFields = textscan(sInterface,'%s','Delimiter','_');
            csFields = csFields{1};
            sInterfaceType = csFields{end};
            sInterface = sInterface(1:end-(length(sInterfaceType) + 1));
            
            iCurrentNumberOfInterfaces = length(csInterface);
            if strcmp(sInterfaceType, 'In')
                 for iInput = 1:length(tSubsystem.Input)
                    tInput = tSubsystem.Input{iInput};
                    if ~isempty(regexp(tInput.label, sInterface, 'once'))
                        csInterface{end+1} = ['''', tSubsystem.label, '_', tInput.label, '_In'''];
                    end
                 end
            else
                 for iOutput = 1:length(tSubsystem.Output)
                    tOutput = tSubsystem.Output{iOutput};
                    if ~isempty(regexp(tOutput.label, sInterface, 'once'))
                        csInterface{end+1} = ['''', tSubsystem.label, '_', tOutput.label, '_Out'''];
                    end
                 end
            end
            if iCurrentNumberOfInterfaces == length(csInterface)
                error(['the import algorithm failed to find the interface ', csInterfaces{iInterface},' of the system ', tSubsystem.label,'. Please check if it actually located in the system (try drag and dropping it elsewhere and then back into the system it belongs to)'])
            end
        end
        
        % now we have all interface and have to define the IF definition
        
        sInterfaceDefinition = ['this.toChildren.', tSubsystem.label, '.setIfFlows('];
        for iInterface = 1:length(csInterface)
            sInterfaceDefinition = [sInterfaceDefinition, csInterface{iInterface}, ', '];
        end
        sInterfaceDefinition = sInterfaceDefinition(1:end-2);
        sInterfaceDefinition = [sInterfaceDefinition, ');\n'];
            
        fprintf(sSystemFile, sInterfaceDefinition);

    end
end

fprintf(sSystemFile, '     	end\n\n');
fprintf(sSystemFile, '      function setIfFlows(this, varargin)\n');

for iChildIF = 1:length(csChildSideInterfaces)
    sChildInterface = ['this.connectIF(', csChildSideInterfaces{iChildIF},', varargin{' num2str(iChildIF), '});\n'];
    fprintf(sSystemFile, sChildInterface);
end

fprintf(sSystemFile, '      end\n\n');
end