function DrawIo(filepath)

% TO DO: P2Ps, Subsystems (e.g. CHX, CCAA, CDRA etc), other F2F types, thermal
% branches, thermal domain in general
% To simplify adding custom P2Ps and F2Fs the program could just create an
% empty general P2P file fitting the current conditions (e.g. static or
% flow)
% Add optional input for branches to specify the custom name


%% Specify which types of xml objects can be translated into V-HAB

% Overall valid types
csValidTypes = {'Store', 'FoodStore', 'Branch', 'System', 'Subsystem', 'Input', 'Output', 'Setup', 'P2P', 'Manipulator', 'HeatSource', 'ThermalBranch', 'ThermalResistance'};

% Add the implemented phases that can be converted
csPhases = {'Gas', 'Gas_Boundary', 'Gas_Flow', 'Liquid', 'Liquid_Boundary', 'Liquid_Flow', 'Solid', 'Solid_Boundary', 'Solid_Flow', 'Mixture', 'Mixture_Boundary', 'Mixture_Flow'};

% Add the implemented library F2Fs that can be converted
csF2F = {'pipe', 'fan_simple', 'fan', 'pump', 'checkvalve', 'valve'};

csSystems = {'Human', 'CDRA', 'CCAA', 'OGA', 'SCRA', 'Subsystem'};

csValidTypes = [csValidTypes, csPhases, csF2F, csSystems];

% extract the data from the XML
[tVHAB_Objects, tConvertIDs]  = extractXML(filepath, csValidTypes);

for iSystem = 1:length(tVHAB_Objects.System)
    tSystemIDtoLabel.( tVHAB_Objects.System{iSystem}.id) =  tVHAB_Objects.System{iSystem}.label;
end

% perform sanity check and provide as good of a debugging output as
% possible if something went wrong
sanityCheckXML_import(tVHAB_Objects, tConvertIDs);

% Associcate the V-HAB components to the systems to simplfiy definition of
% the code later on
tVHAB_Objects = associateComponents(tVHAB_Objects, csPhases, csF2F, csSystems);

% Transform drawio arrows into V-HAB branches
tVHAB_Objects = convertBranches(tVHAB_Objects, csPhases, csF2F, csSystems, tConvertIDs);

% Check System Naming for consitency
for iSystem = 1:length(tVHAB_Objects.System)
    for iCompareSystem = 1:length(tVHAB_Objects.System)
        if iCompareSystem ~= iSystem
            if strcmp(tVHAB_Objects.System{iSystem}.label, tVHAB_Objects.System{iCompareSystem}.label)
                error('The system name %s is used twice in this draw io V-HAB system. This is not possible please provide a different system name for one of the systems!', tVHAB_Objects.System{iCompareSystem}.label)
            end
        end
    end
end

% Create Folders if they do not yet exists
[sSystemLabel, sPath] = createFolders(filepath);

%% Create V-HAB System

% First we loop through the systems and find the overall parent system
% (which has the ID 1)
for iSystem = 1:length(tVHAB_Objects.System)
    if strcmp(tVHAB_Objects.System{iSystem}.ParentID, 'p_1')
        sRootSystemLabel = tVHAB_Objects.System{iSystem}.label;
        break
    end
end

sRootName = tools.normalizePath(sRootSystemLabel);

oMT = matter.table();

%% Create V-HAB Code
createSetupFile(tVHAB_Objects, sPath, sSystemLabel, sRootName, csPhases, csF2F, oMT, tSystemIDtoLabel)

% Create System Files
sPath = [sPath, filesep, '+systems'];
createSystemFiles(tVHAB_Objects, csPhases, csF2F, csSystems, sPath, sSystemLabel, tConvertIDs);


disp('Import Successfull')
end