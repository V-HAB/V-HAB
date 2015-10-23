classdef example_cooledBar_phases < vsys
    %EXAMPLE_COOLEDBAR_PHASES Simple example system for thermal simulation
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function this = example_cooledBar_phases(oParent, sName)
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
            
            % Cross-section area for all blocks: |16 cm^2| in |m^2|.
            fCSArea = 0.0016;
            
            % Initial temperature of all blocks in |K|:
            fTStart = 400;
            
            % Initial specific heat capacity of all blocks in |J/(kg*K)|:
            fCpStart = this.calcAlCp(fTStart);
            
            % Create metal bar (|20 cm| long).
            oBar = matter.store(this, 'Bar', fCSArea*0.2);
            
            % Create one "half" node with |T[start] = 400 K| and an
            % Aluminium phase. Create a capacity and add it to the system.
            % The Aluminium phase should have a density of |2700 kg/m^3|
            % and a specific heat capacity of |fCpStart| (valid for all
            % following blocks as well).
            oBlock1 = this.createAlPhase(this.oMT, oBar, 'Block1', fCSArea*0.025, fTStart, 2700, fCpStart);
            oCapacity1 = this.addCreateCapacity(oBlock1);
            
            % Create three blocks with an Aluminium phase and
            % |T[start] = 400 K| and create/add the capacities to the
            % system.
            oBlock2 = this.createAlPhase(this.oMT, oBar, 'Block2', fCSArea*0.05, fTStart, 2700, fCpStart);
            oCapacity2 = this.addCreateCapacity(oBlock2);
            
            oBlock3 = this.createAlPhase(this.oMT, oBar, 'Block3', fCSArea*0.05, fTStart, 2700, fCpStart);
            oCapacity3 = this.addCreateCapacity(oBlock3);
            
            oBlock4 = this.createAlPhase(this.oMT, oBar, 'Block4', fCSArea*0.05, fTStart, 2700, fCpStart);
            oCapacity4 = this.addCreateCapacity(oBlock4);
            
            % Create one "half" node with an Aluminium phase and
            % |T[start] = 400 K| and create/add the capacity to the system.
            oBlock5 = this.createAlPhase(this.oMT, oBar, 'Block5', fCSArea*0.025, fTStart, 2700, fCpStart);
            oCapacity5 = this.addCreateCapacity(oBlock5);
            
            % Create the environment node with infinite capacity and
            % |T = 295 K|. This uses an Argon gas atmosphere, however the
            % properties are overloaded so it does not matter much what we
            % choose here. 
            %TODO: There should be a standard environment node in the
            % thermal framework so this hack is not needed. 
            oDummyEnv = thermal.dummymatter(this, 'Env', 1000);
            oDummyEnv.addCreatePhase('Ar', 'gas', 295);
            oEnv = thermal.capacity(oDummyEnv.sName, oDummyEnv);
            %oEnv.overloadTotalHeatCapacity(Inf);
            oEnv.makeBoundaryNode();
            this.addCapacity(oEnv);
            
            
            %%
            %START of workaround
            %TODO: Fix V-HAB?
            
            % Looks like we need to register matter objects otherwise the
            % logger (|simulation.masslog|) crashes.
            this.addStore(oBar);
            this.addStore(oDummyEnv);
            
            % Looks like we need to seal the container otherwise a phase
            % update crashes since it does not have a timer. 
            this.seal();
            
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
                thermal.conductors.linear(oCapacity1, oCapacity2, fConductance) ...
            );
            this.addConductor( ...
                thermal.conductors.linear(oCapacity2, oCapacity3, fConductance) ...
            );
            this.addConductor( ...
                thermal.conductors.linear(oCapacity3, oCapacity4, fConductance) ...
            );
            this.addConductor( ...
                thermal.conductors.linear(oCapacity4, oCapacity5, fConductance) ...
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
                    0.8, 1, fCSArea+4*0.001, 1) ...
            );
            
        end
        
    end
    
    methods (Static)
        
        function oPhase = createAlPhase(oMT, oStore, sName, fVolume, fTemperature, fDensity, fSpecificHeatCap)
            % Similar to |thermal.dummymatter.addCreatePhase|, but builds a
            % standard Aluminium phase with the properties provided.
            
            sSubstance = 'Al';
            sPhase = 'solid';
            
            % Create new masses array and fill it with a dummy mass (of the
            % supplied substance) so we can calculate matter properties per
            % mass).
            afMasses = zeros(1, oMT.iSubstances);
            afMasses(oMT.tiN2I.(sSubstance)) = 1;
            
%             % Load substance properties from the matter table: Molar mass.
%             this.fMolarMass = oMT.calculateMolarMass(afMasses);
            
            % Load density from matter table if not provided. 
            if nargin < 6
                fDensity = oMT.calculateDensity(sPhase, afMasses, fTemperature, oMT.Standard.Pressure);
            end
            
            % Load specific heat capacity from matter table if not
            % provided.
            if nargin < 7
                fSpecificHeatCap = oMT.calculateHeatCapacity(sPhase, afMasses, fTemperature, oMT.Standard.Pressure);
            end
            
            % Calculate the mass of the phase (and thus matter object) in 
            % |kg|.
            fMass = fDensity * fVolume;
            
            % Calculate the object's actual heat capacity in |J/K|.
            %this.fHeatCapacity = fMass * fSpecificHeatCap;
            
            % Create path to the correct phase constructor.
            sPhaseCtor = ['matter.phases.', sPhase];
            
            % Create a handle to the correct phase constructor.
            hPhaseCtor = str2func(sPhaseCtor);
            
            % Create and store the single associated phase. 
            oPhase = hPhaseCtor( ...
                oStore, ... % The store.
                sName, ...  % The name of the phase. 
                struct(sSubstance, fMass), ... % "Subphases"
                [], ...     % The volume of the phase.
                fTemperature ... % The temperature of the phase. 
            );
            
            % Overload specific heat capacity if we can.
            if ismethod(oPhase, 'overloadSpecificHeatCapacity')
                oPhase.overloadSpecificHeatCapacity(fSpecificHeatCap);
            end
            
        end
        
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

