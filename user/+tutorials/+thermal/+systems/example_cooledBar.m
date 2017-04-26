classdef example_cooledBar < vsys
    %EXAMPLE_COOLEDBAR Simple example system for thermal simulation.
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function this = example_cooledBar(oParent, sName)
            % Creates a system that is an aluminium bar divided into five
            % thermal nodes. It radiatively cools down to the environment
            % temperature of |295 K|. The environment is modeled as a node
            % with infinite capacity. The bar has an initial temperature of
            % |400 K|. Its capacity and thermal conductivity is temperature
            % dependent. 
            
            % Initialize container and register for the call to the exec
            % method at each second (does not have an influence on thermal
            % analysis). 
            this@vsys(oParent, sName, 1);
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Cross-section area for all blocks: |16 cm^2| in |m^2|.
            fCSArea = 0.0016;
            
            % Initial temperature of all blocks in |K|:
            fTStart = 400;
            
            % Initial specific heat capacity of all blocks in |J/(kg*K)|:
            fCpStart = this.calcAlCp(fTStart);
            
            % Create one "half" node with |T[start] = 400 K| and an
            % Aluminium phase. Create a capacity and add it to the system.
            % The Aluminium phase should have a density of |2700 kg/m^3|
            % and a specific heat capacity of |fCpStart| (valid for all
            % following blocks as well).
            oBlock1 = thermal.dummymatter(this, 'Block1', fCSArea*0.025);
            oBlock1.addCreatePhase('Al', 'solid', fTStart);
            oCapacity1 = this.addCreateCapacity(oBlock1);
            
            % Create three blocks with an Aluminium phase and
            % |T[start] = 400 K| and create/add the capacities to the
            % system.
            oBlock2 = thermal.dummymatter(this, 'Block2', fCSArea*0.05);
            oBlock2.addCreatePhase('Al', 'solid', fTStart);
            oCapacity2 = this.addCreateCapacity(oBlock2);
            
            oBlock3 = thermal.dummymatter(this, 'Block3', fCSArea*0.05);
            oBlock3.addCreatePhase('Al', 'solid', fTStart);
            oCapacity3 = this.addCreateCapacity(oBlock3);
            
            oBlock4 = thermal.dummymatter(this, 'Block4', fCSArea*0.05);
            oBlock4.addCreatePhase('Al', 'solid', 295);
            oCapacity4 = this.addCreateCapacity(oBlock4);
            
            oBlock4 = thermal.dummymatter(this, 'Block5', fCSArea*0.05);
            oBlock4.addCreatePhase('Al', 'solid', 295);
            oCapacity5 = this.addCreateCapacity(oBlock4);
            
            % Create one "half" node with an Aluminium phase and
            % |T[start] = 400 K| and create/add the capacity to the system.
            oBlock5 = thermal.dummymatter(this, 'Block6', fCSArea*0.025);
            oBlock5.addCreatePhase('Al', 'solid', 295);
            oCapacity6 = this.addCreateCapacity(oBlock5);
            
            % Create the environment node with infinite capacity and
            % |T = 295 K|. This uses an Argon gas atmosphere, however the
            % properties are overloaded so it does not matter much what we
            % choose here. 
            %TODO: There should be a standard environment node in the
            % thermal framework so this hack is not needed. 
            oDummyEnv = thermal.dummymatter(this, 'Env', 1000);
            oDummyEnv.addCreatePhase('Ar', 'gas', 295);
            oEnv = thermal.capacity(oDummyEnv.sName, oDummyEnv);
            oEnv.makeBoundaryNode();
%             oEnv.overloadTotalHeatCapacity(Inf);
            this.addCapacity(oEnv);
            
                        
            % Looks like we need to seal the container otherwise a phase
            % update crashes since it does not have a timer. 
%             this.seal();
            
            %END of workaround
            %%
            
            
            % Initial value of conductance for conductive heat transfer.
            % It is calculated with the initial thermal conductivity, 
            % cross-section area and heat flow path length of |l = 0.05 m|.
            fConductance = thermal.transfers.conductive.calculateConductance( ...
                this.calcAlLambda(fTStart), fCSArea, 0.05 ...
            );
            
            % Create and add a linear conductor between each serial block
            % with the initial value of conductance in |W/K|. 
            this.addConductor( ...
                thermal.conductors.linear(this, oCapacity1, oCapacity2, fConductance) ...
            );
            this.addConductor( ...
                thermal.conductors.linear(this, oCapacity2, oCapacity3, fConductance) ...
            );
            this.addConductor( ...
                thermal.conductors.linear(this, oCapacity3, oCapacity4, fConductance) ...
            );
            this.addConductor( ...
                thermal.conductors.linear(this, oCapacity4, oCapacity5, fConductance) ...
            );
            this.addConductor( ...
                thermal.conductors.linear(this, oCapacity5, oCapacity6, fConductance) ...
            );
            
            % Create/add radiative heat transfer between nodes and
            % environment. The environment is assumed to absorb all thermal
            % energy, thus |alpha = 1| and |F = 1|. The emissivity of
            % Aluminium is set to |epsilon = 0.8|. 
            this.addConductor( ...
                thermal.transfers.radiative(oCapacity1, oEnv, ...
                    0.8, 1, fCSArea+4*0.001, 1) ...
            );
            this.addConductor( ...
                thermal.transfers.radiative(oCapacity2, oEnv, ...
                    0.8, 1, 4*0.002, 1) ...
            );
            this.addConductor( ...
                thermal.transfers.radiative(oCapacity3, oEnv, ...
                    0.8, 1, 4*0.002, 1) ...
            );
            this.addConductor( ...
                thermal.transfers.radiative(oCapacity4, oEnv, ...
                    0.8, 1, 4*0.002, 1) ...
            );
            this.addConductor( ...
                thermal.transfers.radiative(oCapacity5, oEnv, ...
                    0.8, 1, 4*0.002, 1) ...
            );
            this.addConductor( ...
                thermal.transfers.radiative(oCapacity6, oEnv, ...
                    0.8, 1, fCSArea+4*0.001, 1) ...
            );
            
        end
        
    end
    
    methods (Static)
        
        function fCp = calcAlCp(fTemp)
            % Calculate a temperature dependent specific heat capacity of
            % Aluminium. 
            fTempGrid = [250 300 345 375 420];
            fAlCpGrid = [862 896 922 939 960];
            fCp = interp1(fTempGrid, fAlCpGrid, fTemp, 'pchip', 'extrap');
        end
        
        function fLambda = calcAlLambda(fTemp)
            % Calculate a temperature dependent thermal conductivity of
            % Aluminium. 
            fTempGrid     = [250 300 345 375 420];
            fAlLambdaGrid = [235 237 240 241 239];
            fLambda = interp1(fTempGrid, fAlLambdaGrid, fTemp, 'linear', 'extrap');
        end
        
    end
    
end

