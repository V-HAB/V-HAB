classdef Example < vsys
    %EXAMPLE 
    
    properties 
        
    end
    
    methods
        function this = Example(oParent, sName)
            % Call parent constructor. Third parameter defined how often
            % the .exec() method of this subsystem is called. This can be
            % used to change the system state, e.g. close valves or switch
            % on/off components.
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical false (def) means
            % the .exec method is called when the oParent.exec() is
            % executed (see this .exec() method - always call exec@vsys as
            % well!).
            this@vsys(oParent, sName);
            
            % Make the system configurable
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        function createElectricalStructure(this)
            createElectricalStructure@vsys(this);
            
            % Create circuit
            oCircuit = electrical.circuit(this, 'ExampleCircuit');
            
            % Create source
            electrical.stores.constantVoltageSource(oCircuit, 'VoltageSource', 'DC', 100);
            
            % Create resistors
            electrical.components.resistor(oCircuit, 'Resistor1', 1000);
            electrical.components.resistor(oCircuit, 'Resistor2', 1000);
            electrical.components.resistor(oCircuit, 'Resistor3', 1000);
            
            % Create two nodes
            oNode1 = electrical.node(oCircuit, 'Node_1');
            oNode2 = electrical.node(oCircuit, 'Node_2');
            
            % Creating four terminals for the two nodes
            electrical.terminal(oNode1,  1);
            electrical.terminal(oNode1, -1);
            electrical.terminal(oNode2,  1);
            electrical.terminal(oNode2, -1);
            
            % Create electrical branches
            electrical.branch(oCircuit, 'VoltageSource.positive', {'Resistor1'}, 'Node_1.Terminal_1');
            electrical.branch(oCircuit, 'Node_1.Terminal_2',      {'Resistor2'}, 'Node_2.Terminal_1');
            electrical.branch(oCircuit, 'Node_2.Terminal_2',      {'Resistor3'}, 'VoltageSource.negative');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
        end
        
     end
    
end

