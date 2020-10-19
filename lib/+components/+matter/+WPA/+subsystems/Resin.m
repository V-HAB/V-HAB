classdef Resin < vsys
    %creating resins for the MFBeds
    % in my Bachelor thesis: Dynamic modeling of the Water Processor Assembly of the International Space Station,
    % in chapter 3.21
    properties (SetAccess = protected, GetAccess = public)
        iCells;        %amount of discretized iCells 
        
        rVoidFraction;      % [] Volume_absorber/Volume_total []-->bulk
        fResinMass ;        % [kg] Mass of resine
        fTotalCapacity;     % Total Capacity in [eq/kg] 
        fVolume;            % Total Volume of the bed [m^3]
        bCationResin = true;% Cation or Anionbed
        bStrong = true;     % identifies the resin type, if parameter is true, strong resine is used, otherwise weak resine
        iPresaturant;
        
        abContaminants;
    end
    
    methods
        function this = Resin(oParent, sName, rVoidFraction, fResinMass, fTotalCapacity, fVolume, bCationResin, bStrong, iCells)
            this@vsys(oParent, sName, inf);
            eval(this.oRoot.oCfgParams.configCode(this));
            this.rVoidFraction  = rVoidFraction;
            this.fResinMass     = fResinMass;
            this.fTotalCapacity = fTotalCapacity;
            this.fVolume        = fVolume;
            this.bCationResin  	= bCationResin; % Cation or Anionbed
            this.bStrong        = bStrong;
            
            this.iCells         = iCells;
            
            
        end
    
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Resin', this.fVolume);
            fVolumeFilter = this.fVolume;                    
            
            %creating Ion phases and presaturing them
            if this.bCationResin
                this.iPresaturant = this.oMT.tiN2I.Hplus;
                tfIonMasses = struct('Hplus',   (this.fResinMass * this.fTotalCapacity * this.oMT.afMolarMass(this.iPresaturant))    / this.iCells);
            else
                this.iPresaturant = this.oMT.tiN2I.OH;
                tfIonMasses = struct('OH', (this.fResinMass * this.fTotalCapacity * this.oMT.afMolarMass(this.iPresaturant))  / this.iCells);
            end
            
            this.abContaminants = false(1, this.oMT.iSubstances);
            
            % Creates Phases for the cells and the P2Ps between the ion and
            % water phases
            for iCell = 1 : this.iCells
                % The water phased is defined via the volume and as flow
                % phase. The volume is assumed the void volume of this
                % specific filter
                oWaterPhase = this.toStores.Resin.createPhase('mixture', 'flow', ['Water_', num2str(iCell)], 'liquid', this.rVoidFraction * fVolumeFilter / this.iCells, struct('H2O', 1), 293, 1e5);
                
                % The resine is defined with the specific mass, as that is
                % later on important for the calculations
                oResinPhase = matter.phases.mixture(this.toStores.Resin, ['Resin_', num2str(iCell)],   'liquid',   tfIonMasses, 	293,    1e5);
                
                % Now add a P2P for the flows beeing desorbed (having
                % the other sign as the ones calculated as the flows above)
                oDesorptionP2P = components.matter.WPA.components.Desorption_P2P(      this.toStores.Resin, ['Ion_Desorption_P2P', num2str(iCell)], oWaterPhase, oResinPhase);
                    
                % Now add the P2P
                if this.bStrong
                    oP2P = components.matter.WPA.components.MixedBed_P2P(      this.toStores.Resin, ['Ion_P2P', num2str(iCell)], oWaterPhase, oResinPhase, oDesorptionP2P);
                else
                    oP2P = components.matter.WPA.components.WeakBaseAnion_P2P( this.toStores.Resin, ['Ion_P2P', num2str(iCell)], oWaterPhase, oResinPhase, oDesorptionP2P);
                end
                this.abContaminants = this.abContaminants | oP2P.abIons;
                
                % For all defined cells we also define a branch between the
                % cell and its previous cell
                if iCell > 1
                    matter.branch(this, oPreviousWaterPhase,    {}, oWaterPhase, ['Cell_',num2str(iCell-1),'_to_Cell_',num2str(iCell)]);
                end
                
                components.matter.pH_Module.flowManip(['pH_Manipulator_', num2str(iCell)], oWaterPhase);
                
                oPreviousWaterPhase = oWaterPhase;
            end
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            % This is a special case, we use one multi branch solver to
            % solve the whole WPA system, therefore these subsystems do
            % not define their solvers! If this is used outside the WPA you
            % have to define the solvers when you define the subsystem
            this.setThermalSolvers();
            
            
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    tTimeStepProperties.fMaxStep = this.oParent.oParent.fTimeStep * 5;

                    oPhase.setTimeStepProperties(tTimeStepProperties);

                    tTimeStepProperties = struct();
                    tTimeStepProperties.fMaxStep = this.oParent.oParent.fTimeStep * 5;
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                end
            end
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
        end
    end
end

