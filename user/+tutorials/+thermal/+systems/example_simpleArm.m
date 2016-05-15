classdef example_simpleArm < vsys
    %EXAMPLE_SIMPLEARM Simple example system for thermal simulation.
    
    properties
        
        oThermalSolver; % The thermal solver object ? only needed for logging :(
        
        % Default specific heat capacity (blood).
        fSpecificHeatCap = 3600; % [J/(kgK)]

        % Default mass flow rate (blood/arm/shoulder).
        fMassFlowRate = 0.014; % [kg/s]
            
    end
    
    methods
        
        function this = example_simpleArm(oParent, sName)
            % This is a five node simple arm model. All values are
            % guesstimated and do not represent real physical properties of
            % body tissue or blood. 
            
            % Initialize container and register for the call to the exec
            % method at each second (does not have an influence on thermal
            % analysis). 
            this@vsys(oParent, sName, 60);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %fDensity = 1000; % [kg/m^3]
            
            fTStart = 308; % [K]
            
            mfVolumeSurface = [ ...
                % Volume, Surface (adjusted)
                 904.8e-6, 22.62e-3; % shoulder: |12 cm| diameter sphere, 50% surface
                1571.0e-6, 62.83e-3; % upper arm: |10 cm| diameter cylinder, |20 cm| long, barrel surface
                 381.7e-6, 12.73e-3; % elbow: |9 cm| diameter sphere, 50% surface
                1106.0e-6, 55.29e-3; % lower arm: |8 cm| diameter cylinder, |22 cm| long, barrel surface
                 594.0e-6, 54.15e-3; % hand: cuboid |18*11*3 cm^3|, 95% surface
            ];
            
            % Create arm.
            oArm = matter.store(this, 'Arm', sum(mfVolumeSurface(:, 1)));
            
            % Shoulder (boundary node with fixed temperature)
            oShoulder = this.createTissuePhase(this.oMT, oArm, 'Arm__Arm1Shoulder', mfVolumeSurface(1, 1), fTStart+1);
            oCapacity1 = thermal.capacity(oShoulder.sName, oShoulder);
            oCapacity1.makeBoundaryNode();
%             oCapacity1.overloadTotalHeatCapacity(Inf);
            this.addCapacity(oCapacity1);
            
            % Upper arm.
            oUpperArm = this.createTissuePhase(this.oMT, oArm, 'Arm2Upper', mfVolumeSurface(2, 1), fTStart+0.8);
            oCapacity2 = this.addCreateCapacity(oUpperArm);
            
            % Elbow joint.
            oElbow = this.createTissuePhase(this.oMT, oArm, 'Arm3Elbow', mfVolumeSurface(3, 1), fTStart+0.5);
            oCapacity3 = this.addCreateCapacity(oElbow);
            
            % Lower arm.
            oLowerArm = this.createTissuePhase(this.oMT, oArm, 'Arm4Lower', mfVolumeSurface(4, 1), fTStart+0.2);
            oCapacity4 = this.addCreateCapacity(oLowerArm);
            
            % Hand.
            oHand = this.createTissuePhase(this.oMT, oArm, 'Arm5Hand', mfVolumeSurface(5, 1), fTStart-0.7);
            oCapacity5 = this.addCreateCapacity(oHand);
            
            
            % Create environment node with infinite capacity and 
            % |T = 295 K|. This uses an Argon gas atmosphere, however the
            % properties are overloaded so it does not matter much what we
            % choose here. 
            oDummyEnv = thermal.dummymatter(this, 'Env', 1000);
            oDummyEnv.addCreatePhase('Ar', 'gas', 295);
            oEnv = thermal.capacity(oDummyEnv.sName, oDummyEnv);
            oEnv.makeBoundaryNode();
%             oEnv.overloadTotalHeatCapacity(Inf);
            this.addCapacity(oEnv);
            
            %%
            %START of workaround
            %TODO: Fix V-HAB?
            
            % Looks like we need to register matter objects otherwise the
            % logger (|simulation.masslog|) crashes.
%             this.addStore(oArm);
%             this.addStore(oDummyEnv);
            
            % Looks like we need to seal the container otherwise a phase
            % update crashes since it does not have a timer. 
            %this.seal();
            
            %END of workaround
            %%
            
            % Create and add fluidic conductors between each segment.
            this.addConductor( ...
                thermal.transfers.fluidic(oCapacity1, oCapacity2, this.fSpecificHeatCap, 1.00*this.fMassFlowRate) ...
            );
            this.addConductor( ...
                thermal.transfers.fluidic(oCapacity2, oCapacity1, this.fSpecificHeatCap, 1.00*this.fMassFlowRate) ...
            );
            
            this.addConductor( ...
                thermal.transfers.fluidic(oCapacity2, oCapacity3, this.fSpecificHeatCap, 0.52*this.fMassFlowRate) ...
            );
            this.addConductor( ...
                thermal.transfers.fluidic(oCapacity3, oCapacity2, this.fSpecificHeatCap, 0.52*this.fMassFlowRate) ...
            );
            
            this.addConductor( ...
                thermal.transfers.fluidic(oCapacity3, oCapacity4, this.fSpecificHeatCap, 0.48*this.fMassFlowRate) ...
            );
            this.addConductor( ...
                thermal.transfers.fluidic(oCapacity4, oCapacity3, this.fSpecificHeatCap, 0.48*this.fMassFlowRate) ...
            );
            
            this.addConductor( ...
                thermal.transfers.fluidic(oCapacity4, oCapacity5, this.fSpecificHeatCap, 0.08*this.fMassFlowRate) ...
            );
            this.addConductor( ...
                thermal.transfers.fluidic(oCapacity5, oCapacity4, this.fSpecificHeatCap, 0.08*this.fMassFlowRate) ...
            );
            
            % Create/add radiative heat transfer between nodes and
            % environment. The environment is assumed to absorb all thermal
            % energy, thus |alpha = 1| and |F = 1|. The emissivity of the
            % skin is set to |epsilon = 0.9|. 
            this.addConductor( ...
                thermal.transfers.radiative(oCapacity1, oEnv, ...
                    0.9, 1, mfVolumeSurface(1, 2), 1) ...
            );
            this.addConductor( ...
                thermal.transfers.radiative(oCapacity2, oEnv, ...
                    0.9, 1, mfVolumeSurface(2, 2), 1) ...
            );
            this.addConductor( ...
                thermal.transfers.radiative(oCapacity3, oEnv, ...
                    0.9, 1, mfVolumeSurface(3, 2), 1) ...
            );
            this.addConductor( ...
                thermal.transfers.radiative(oCapacity4, oEnv, ...
                    0.9, 1, mfVolumeSurface(4, 2), 1) ...
            );
            this.addConductor( ...
                thermal.transfers.radiative(oCapacity5, oEnv, ...
                    0.9, 1, mfVolumeSurface(5, 2), 1) ...
            );
            
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
        end
        
    end
    
    methods (Static)
        
        function oPhase = createTissuePhase(oMT, oStore, sName, fVolume, fTemperature)
            % Similar to |thermal.dummymatter.addCreatePhase|.
            
            
            sSubstance = 'Human';%'DummyTissue';
            sPhase = 'solid';
            
            % Create new masses array and fill it with a dummy mass (of the
            % supplied substance) so we can calculate matter properties per
            % mass).
            afMasses = zeros(1, oMT.iSubstances);
            afMasses(oMT.tiN2I.(sSubstance)) = 1;
            
            % Calculate the mass of the phase (and thus matter object) in 
            % |kg|.
            %fMass = oMT.calculateDensity(sPhase, afMasses, fTemperature, oMT.Standard.Pressure) * fVolume;
            fMass = oMT.ttxMatter.(sSubstance).ttxPhases.tSolid.Density * fVolume;
            
            % Create path to the correct phase constructor.
            sPhaseCtor = ['matter.phases.', sPhase];
            
            % Create a handle to the correct phase constructor.
            hPhaseCtor = str2func(sPhaseCtor);
            
            % Create and store the single associated phase. 
            % The solid phase constructor ignores the volume, so we do the
            % same with the input parameter. It is left intact in the
            % constructor of this example system, so in the future it may
            % be changed. 
            oPhase = hPhaseCtor( ...
                oStore, ... % The store.
                sName, ...  % The name of the phase. 
                struct(sSubstance, fMass), ... % "Subphases"
                [], ...     % The volume of the phase
                fTemperature ... % The temperature of the phase. 
            );
            
        end
        
    end
    
end

