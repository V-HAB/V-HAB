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
            electrical.stores.constantVoltageSource(oCircuit, 'VoltageSource', 'DC', 6);
            
            % Create resistors
            electrical.components.resistor(oCircuit, 'Resistor1', 7.5);
            electrical.components.resistor(oCircuit, 'Resistor2', 30);
            electrical.components.resistor(oCircuit, 'Resistor3', 3);
            electrical.components.resistor(oCircuit, 'Resistor4', 3.75);
            electrical.components.resistor(oCircuit, 'Resistor5', 15);
            electrical.components.resistor(oCircuit, 'Resistor6', 3);
            
            % Create five nodes
            oNode1 = electrical.node(oCircuit, 'Node_1');
            oNode2 = electrical.node(oCircuit, 'Node_2');
            oNode3 = electrical.node(oCircuit, 'Node_3');
            oNode4 = electrical.node(oCircuit, 'Node_4');
            oNode5 = electrical.node(oCircuit, 'Node_5');
            
            % Creating terminals using the createTerminals() method. The
            % argument is the number of terminals that shall be created. 
            % TODO Add more explanation here and an example of how one
            % would do it by manually calling electrical.terminal.
            oNode1.createTerminals(4);
            oNode2.createTerminals(3);
            oNode3.createTerminals(3);
            oNode4.createTerminals(3);
            oNode5.createTerminals(3);
            
            % Create electrical branches
            % The branches here are defined exactly as shown in the circuit
            % diagram contained in this tutorial. Note that there are three
            % branches that do not contain any resistances or any
            % components for that matter. These do not have to be given
            % here, it is just to show that the solver will take care of
            % this and combine the nodes internally. 
            electrical.branch(oCircuit, 'Node_1.Terminal_4',      {'Resistor1'}, 'Node_5.Terminal_1');
            electrical.branch(oCircuit, 'Node_1.Terminal_2',      {'Resistor2'}, 'Node_3.Terminal_1');
            electrical.branch(oCircuit, 'Node_1.Terminal_3',      {'Resistor3'}, 'Node_2.Terminal_1');
            electrical.branch(oCircuit, 'Node_2.Terminal_2',      {'Resistor4'}, 'Node_4.Terminal_1');
            electrical.branch(oCircuit, 'Node_2.Terminal_3',      {'Resistor5'}, 'Node_3.Terminal_2');
            electrical.branch(oCircuit, 'VoltageSource.positive', {'Resistor6'}, 'Node_1.Terminal_1');
            electrical.branch(oCircuit, 'Node_3.Terminal_3',      {},            'Node_4.Terminal_2');
            electrical.branch(oCircuit, 'Node_4.Terminal_3',      {},            'Node_5.Terminal_2');
            electrical.branch(oCircuit, 'Node_5.Terminal_3',      {},            'VoltageSource.negative');
            
            
            
            
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.electrical.circuit(this.toCircuits.ExampleCircuit);
            
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

