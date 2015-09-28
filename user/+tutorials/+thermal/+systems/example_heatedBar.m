classdef example_heatedBar < vsys
    %EXAMPLE_HEATEDBAR Simple example system for thermal simulation.
    
    properties
        
        oThermalSolver; % The thermal solver object ? only needed for logging :(
        
    end
    
    methods
        
        function this = example_heatedBar(oParent, sName)
            % Creates a system that is an adiabatic aluminium bar divided
            % into five thermal nodes. The first node has a |100 W| heat
            % source attached to it, the last node has infinite capacity 
            % (i.e., a heat sink to an infinite space).
            
            % Initialize container and register for the call to the exec
            % method at each second (does not have an influence on thermal
            % analysis). 
            this@vsys(oParent, sName, 1);
            
            % Cross-section area for all blocks: |16 cm^2| in |m^2|.
            fCSArea = 0.0016;
            
            % Create one "half" node with an Aluminium phase and
            % |T[start] = 50 °C| and attach a simple |100 W| heat source to
            % it. Create a capacity and add it to the system (== |tsys|).
            % The Aluminium phase should have a density of |2700 kg/m^3|
            % and a specific heat capacity of |900 J/(kg*K)| (valid for all
            % following blocks as well).
            oBlock1 = thermal.dummymatter(this, 'Block1', fCSArea*0.025);
            oBlock1.addCreatePhase('DummyAlu', 'solid', 50+273.15);
            oHeatSource = thermal.heatsource('HeaterAtBlock1', 100);
            oCapacity1 = this.addCreateCapacity(oBlock1, oHeatSource);
            
            % Create three blocks with an Aluminium phase and
            % |T[start] = 50 °C| and create/add the capacity to the system.
            oBlock2 = thermal.dummymatter(this, 'Block2', fCSArea*0.05);
            oBlock2.addCreatePhase('DummyAlu', 'solid', 50+273.15);
            oCapacity2 = this.addCreateCapacity(oBlock2);
            
            oBlock3 = thermal.dummymatter(this, 'Block3', fCSArea*0.05);
            oBlock3.addCreatePhase('DummyAlu', 'solid', 50+273.15);
            oCapacity3 = this.addCreateCapacity(oBlock3);
            
            oBlock4 = thermal.dummymatter(this, 'Block4', fCSArea*0.05);
            oBlock4.addCreatePhase('DummyAlu', 'solid', 50+273.15);
            oCapacity4 = this.addCreateCapacity(oBlock4);
            
            % Create one "half" block with an Aluminium phase and
            % |T = 20 °C|. Overload the matter object's heat capacity with
            % an |inifinite| capacity (heat sink) on the |oCapacity5|
            % capacity object. Add the capacity to the |tsys|.
            oBlock5 = thermal.dummymatter(this, 'Block5', fCSArea*0.025);
            oBlock5.addCreatePhase('DummyAlu', 'solid', 20+273.15);
            oCapacity5 = thermal.capacity(oBlock5.sName, oBlock5);
            oCapacity5.overloadTotalHeatCapacity(Inf);
            this.addCapacity(oCapacity5);
            
            %%
            %START of workaround
            %TODO: Fix V-HAB?
            
            % Looks like we need to register matter objects otherwise the
            % logger (|simulation.masslog|) crashes.
            this.addStore(oBlock1);
            this.addStore(oBlock2);
            this.addStore(oBlock3);
            this.addStore(oBlock4);
            this.addStore(oBlock5);
            
            % Looks like we need to seal the container otherwise a phase
            % update crashes since it does not have a timer. 
            this.seal();
            
            %END of workaround
            %%
            
            % Create and add linear conductors between each serial block
            % with a conductance value of |GL = 7.68 W/K|.
            this.addConductor( ...
                thermal.conductors.linear(oCapacity1, oCapacity2, 7.68) ...
            );
            this.addConductor( ...
                thermal.conductors.linear(oCapacity2, oCapacity3, 7.68) ...
            );
            this.addConductor( ...
                thermal.conductors.linear(oCapacity3, oCapacity4, 7.68) ...
            );
            this.addConductor( ...
                thermal.conductors.linear(oCapacity4, oCapacity5, 7.68) ...
            );
                        
        end
        
    end
    
     methods (Access = protected)
        
        function exec(this, varargin)
            
%             if mod(this.oTimer.iTick, 500) == 0
%                 disp(varargin{:});
%             end
            exec@vsys(this);
            
        end
        
     end
    
end

