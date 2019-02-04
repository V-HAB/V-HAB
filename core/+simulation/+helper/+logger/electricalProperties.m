function tLogProps = electrical_properties(tLogProps, oVsys, csCircuits)
% ELECTRICAL_PROPERTIES Logs typically relevant electrical properties
%   Logs branch currents, node voltages, resistances, powers  



if nargin < 3 || isempty(csCircuits)
    csCircuits = fieldnames(oVsys.toCircuits);
end

sPath = simulation.helper.paths.getSysPath(oVsys);


iV = 1;


for iC = 1:length(csCircuits)
    oCircuit     = oVsys.toCircuits.(csCircuits{iC});
    sCircuitPath = [ sPath, '.toCircuits.', oCircuit.sName ];
    
    % Stores
    for iS = 1:length(oCircuit.aoStores)
        oStore = oCircuit.aoStores(iS);
        sStorePath = [ sCircuitPath, '.toStores.', oStore.sName ];
        
        % Capacity
        tLogProps(iV).sObjectPath = sStorePath;
        tLogProps(iV).sExpression = 'fCapacity';
        tLogProps(iV).sLabel = [ 'Store Capacity (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oStore.sName, ')' ];
        iV = iV + 1;
        
        % Not yet implemented.
%         if isa(oStore, 'electrical.stores.constantVoltageSource')
%             % Current
%             tLogProps(iV).sObjectPath = sStorePath;
%             tLogProps(iV).sExpression = 'fCurrent';
%             tLogProps(iV).sLabel = [ 'Store Current (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oStore.sName, ')' ];
%             iV = iV + 1;
%         end
%         
%         if isa(oStore, 'electrical.stores.constantCurrentSource')
%             % Voltage
%             tLogProps(iV).sObjectPath = sStorePath;
%             tLogProps(iV).sExpression = 'fVoltage';
%             tLogProps(iV).sLabel = [ 'Store Voltage (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oStore.sName, ')' ];
%             iV = iV + 1;
%         end
    end
    
    % Nodes
    for iN = 1:length(oCircuit.aoNodes)
        oNode = oCircuit.aoNodes(iN);
        sNodePath = [ sCircuitPath, '.toNodes.', oNode.sName ];
        
        % Voltage
        tLogProps(iV).sObjectPath = sNodePath;
        tLogProps(iV).sExpression = 'fVoltage';
        tLogProps(iV).sLabel = [ 'Node Voltage (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oNode.sName, ')' ];
        iV = iV + 1;

    end
    
    % Branches
    for iB = 1:length(oCircuit.aoBranches)
        oBranch = oCircuit.aoBranches(iB);
        sBranchPath = [ sCircuitPath, '.toBranches.', oBranch.sName ];
        
        % Current
        tLogProps(iV).sObjectPath = sBranchPath;
        tLogProps(iV).sExpression = 'fCurrent';
        tLogProps(iV).sLabel = [ 'Branch Current (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oBranch.sName, ')' ];
        iV = iV + 1;
        
        % Resistance
        tLogProps(iV).sObjectPath = sBranchPath;
        tLogProps(iV).sExpression = 'fResistance';
        tLogProps(iV).sLabel = [ 'Branch Resistance (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oBranch.sName, ')' ];
        iV = iV + 1;

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
            % Current
            tLogProps(iV).sObjectPath = sComponentPath;
            tLogProps(iV).sExpression = 'fCurrent';
            tLogProps(iV).sLabel = [ 'Resistor Current (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oComponent.sName, ')' ];
            iV = iV + 1;
            
            % Resistance
            tLogProps(iV).sObjectPath = sComponentPath;
            tLogProps(iV).sExpression = 'fResistance';
            tLogProps(iV).sLabel = [ 'Resistor Resistance (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oComponent.sName, ')' ];
            iV = iV + 1;
            
             % Voltage drop
            tLogProps(iV).sObjectPath = sComponentPath;
            tLogProps(iV).sExpression = 'fVoltageDrop';
            tLogProps(iV).sLabel = [ 'Resistor Voltage Drop (', oVsys.sName, ' - ', oCircuit.sName, ' - ', oComponent.sName, ')' ];
            iV = iV + 1;
        end
        
        % Transistors
        %TODO Implement

    end
    
end

