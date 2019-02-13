function tLogProps = electricalProperties(tLogProps, oVsys, csCircuits)
% ELECTRICALPROPERTIES Logs typically relevant electrical properties
%   Logs branch currents, node voltages, resistances, powers in all
%   circuits provided in the csCircuits input argument. If this is left
%   empty, the function will return the logging properties for all circuits
%   in the provided system.

% First we need to check if the provided object is a vsys, because the
% generic logger-helper-interface also accepts other types.
if ~isa(oVsys, 'vsys')
    error('The provided object (%s) is not a vsys. Electrical properties can only be logged in vsys objects, specifically electical.containers.', oVsys.sName);
end

% Checking to see if the user provided a specific circuit to log. If not,
% we log all of them. 
if nargin < 3 || isempty(csCircuits)
    csCircuits = fieldnames(oVsys.toCircuits);
end

% Getting the path to the system object that contains the circuits we want
% to log. 
sPath = simulation.helper.paths.getSystemPath(oVsys);

% Initializing a counter
iNumberOfValues = 1;

% Now we loop through all electrical circuits
for iCircuit = 1:length(csCircuits)
    % Getting a reference to the current circuit
    oCircuit     = oVsys.toCircuits.(csCircuits{iCircuit});
    
    % Getting the path to the current circuit
    sCircuitPath = [ sPath, '.toCircuits.', oCircuit.sName ];
    
    % Now we loop through all electrical stores
    for iStore = 1:length(oCircuit.aoStores)
        % Getting a reference to the current store
        oStore = oCircuit.aoStores(iStore);
        
        % Getting a path to the current store
        sStorePath = [ sCircuitPath, '.toStores.', oStore.sName ];
        
        % Adding the path to the store
        tLogProps(iNumberOfValues).sObjectPath = sStorePath;
        
        % Adding an expression that will be eval'd to extract the actual
        % log value from the object
        tLogProps(iNumberOfValues).sExpression = 'fCapacity';
        
        % Adding a label that will be used during plotting in the legend
        tLogProps(iNumberOfValues).sLabel = [ 'Store Capacity (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oStore.sName, ')' ];
        
        % Incrementing the value counter
        iNumberOfValues = iNumberOfValues + 1;
        
        % If this store is a constant voltage source we can log its current
        % as well.
        if isa(oStore, 'electrical.stores.constantVoltageSource')
            % Adding the path to the store
            tLogProps(iNumberOfValues).sObjectPath = sStorePath;
            
            % Adding an expression that will be eval'd to extract the
            % actual log value from the object
            tLogProps(iNumberOfValues).sExpression = 'oPositiveTerminal.oFlow.fCurrent';
            
            % Adding a label that will be used during plotting in the legend
            tLogProps(iNumberOfValues).sLabel = [ 'Store Current (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oStore.sName, ')' ];
            
            % Incrementing the value counter
            iNumberOfValues = iNumberOfValues + 1;
        end
        
        % Not yet implemented.
%         if isa(oStore, 'electrical.stores.constantCurrentSource')
%             % Voltage
%             tLogProps(iNumberOfValues).sObjectPath = sStorePath;
%             tLogProps(iNumberOfValues).sExpression = 'fVoltage';
%             tLogProps(iNumberOfValues).sLabel = [ 'Store Voltage (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oStore.sName, ')' ];
%             iNumberOfValues = iNumberOfValues + 1;
%         end
    end
    
    % Now we loop through all of the nodes
    for iNode = 1:length(oCircuit.aoNodes)
        % Getting a reference to the current node
        oNode = oCircuit.aoNodes(iNode);
        
        % Getting the path to the current node
        sNodePath = [ sCircuitPath, '.toNodes.', oNode.sName ];
        
        % Adding the path to the node
        tLogProps(iNumberOfValues).sObjectPath = sNodePath;
        
        % Adding an expression that will be eval'd to extract the actual
        % log value from the object
        tLogProps(iNumberOfValues).sExpression = 'fVoltage';
        
        % Adding a label that will be used during plotting in the legend
        tLogProps(iNumberOfValues).sLabel = [ 'Node Voltage (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oNode.sName, ')' ];
        
        % Incrementing the value counter
        iNumberOfValues = iNumberOfValues + 1;

    end
    
    % Now we're looping through all of the branches in the circuit
    for iB = 1:length(oCircuit.aoBranches)
        % Getting a reference to the branch object
        oBranch = oCircuit.aoBranches(iB);
        
        % Getting the path to the branch object
        sBranchPath = [ sCircuitPath, '.toBranches.', oBranch.sName ];
        
        %% Current 
        
        % Adding the branch path 
        tLogProps(iNumberOfValues).sObjectPath = sBranchPath;
        
        % Adding an expression that will be eval'd to extract the actual
        % log value from the object
        tLogProps(iNumberOfValues).sExpression = 'fCurrent';
        
        % Adding a label that will be used during plotting in the legend
        tLogProps(iNumberOfValues).sLabel = [ 'Branch Current (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oBranch.sName, ')' ];
        
        % Incrementing the value counter
        iNumberOfValues = iNumberOfValues + 1;
        
        %% Resistance
        
        % Adding the path to the component
        tLogProps(iNumberOfValues).sObjectPath = sBranchPath;
        
        % Adding an expression that will be eval'd to extract the actual
        % log value from the object
        tLogProps(iNumberOfValues).sExpression = 'fResistance';
        
        % Adding a label that will be used during plotting in the legend
        tLogProps(iNumberOfValues).sLabel = [ 'Branch Resistance (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oBranch.sName, ')' ];
        
        % Incrementing the value counter
        iNumberOfValues = iNumberOfValues + 1;

    end
    
    % Components
    for iComponent = 1:length(oCircuit.aoComponents)
        oComponent = oCircuit.aoComponents(iComponent);
        sComponentPath = [ sCircuitPath, '.toComponents.', oComponent.sName ];
        
        % Capacitors
        %TODO Implement
        
        % Diodes
        %TODO Implement
        
        % Inductors
        %TODO Implement
        
        % Interruptors
        %TODO Implement
        
        % Resistors
        if isa(oComponent, 'electrical.components.resistor')
            %% Current
            
            % Adding the path to the component
            tLogProps(iNumberOfValues).sObjectPath = sComponentPath;
            
            % Adding an expression that will be eval'd to extract the
            % actual log value from the object
            tLogProps(iNumberOfValues).sExpression = 'fCurrent';
            
            % Adding a label that will be used during plotting in the legend
            tLogProps(iNumberOfValues).sLabel = [ 'Resistor Current (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oComponent.sName, ')' ];
            
            % Incrementing the value counter
            iNumberOfValues = iNumberOfValues + 1;
            
            %% Resistance
            
            % Adding the path to the component
            tLogProps(iNumberOfValues).sObjectPath = sComponentPath;
            
            % Adding an expression that will be eval'd to extract the
            % actual log value from the object
            tLogProps(iNumberOfValues).sExpression = 'fResistance';
            
            % Adding a label that will be used during plotting in the legend
            tLogProps(iNumberOfValues).sLabel = [ 'Resistor Resistance (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oComponent.sName, ')' ];
            
            % Incrementing the value counter
            iNumberOfValues = iNumberOfValues + 1;
            
            %% Voltage drop
            
            % Adding the path to the component
            tLogProps(iNumberOfValues).sObjectPath = sComponentPath;
            
            % Adding an expression that will be eval'd to extract the
            % actual log value from the object
            tLogProps(iNumberOfValues).sExpression = 'fVoltageDrop';
            
            % Adding a label that will be used during plotting in the legend
            tLogProps(iNumberOfValues).sLabel = [ 'Resistor Voltage Drop (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oComponent.sName, ')' ];
            
            % Incrementing the value counter
            iNumberOfValues = iNumberOfValues + 1;
        end
        
        % Transistors
        %TODO Implement

    end
    
end

