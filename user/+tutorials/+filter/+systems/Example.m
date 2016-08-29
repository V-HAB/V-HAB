classdef Example < vsys

    properties
        
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName);
            % Adding the subsystem
            
            
        	tInitialization.tfMassAbsorber  =   struct('Zeolite5A',1);
            tInitialization.tfMassFlow      =   struct('N2',1);
            tInitialization.fTemperature    =   293;
            tInitialization.fFlowVolume     =   1;
            tInitialization.fAbsorberVolume =   1;
            tInitialization.iCellNumber     =   10;
            
            components.filter.Filter(this, 'Filter', tInitialization);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Cabin', 100);
            
            % Adding a phase to the store 'Tank_1', 2 m^3 air
            oGasPhase = this.toStores.Cabin.createPhase('air', 100);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oGasPhase, 'Port_2');
            
            
                        
            %% Adding some pipes
            components.pipe(this, 'Pipe1', 1, 0.005);
            components.pipe(this, 'Pipe2', 1, 0.005);
            
            % Creating the flowpath (=branch) into a subsystem
            % Input parameter format is always: 
            % 'Interface port name', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'SubsystemInput', {'Pipe1'}, 'Cabin.Port_1');
            
            % Creating the flowpath (=branch) out of a subsystem
            % Input parameter format is always: 
            % 'Interface port name', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'SubsystemOutput', {'Pipe2'}, 'Cabin.Port_2');
            
            
            
            
            %%% NOTE!!! setIfFlows has to be done in createMatterStructure!
            
            % Now we need to connect the subsystem with the top level system (this one). This is
            % done by a method provided by the subsystem.
            this.toChildren.Filter.setIfFlows('SubsystemInput', 'SubsystemOutput');
            
            
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            %this.seal();
            % NOT ANY MORE!
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            % SOLVERS ETC!
            
            % specific properties for rMaxChange etc, possibly depending on
            % this.tSolverProperties.XXX
            % OR this.oRoot.tSolverProperties !!!
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

