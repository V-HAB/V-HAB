classdef MultifiltrationBED < vsys
    %creates the MFBed from the different beds(resins)
    % in my Bachelor thesis: Dynamic modeling of the Water Processor Assembly of the International Space Station,
    % in chapter 3.21
    properties (SetAccess = protected, GetAccess = public)
        % increase of speed by decreasing max capacity of MFBeds, used as a
        % fitting parameter, check if the issue can be solved without using
        % it
        fSpeed = 1;
        
        % Parameter to decide if this models a pure ion exchange bed
        % without organic removal
        bIonBed = false;
        
        mfTotalCapacity;
        mfCurrentFillState;
        
        abContaminants;
    end
    
    methods
        function this = MultifiltrationBED(oParent, sName, miCells, fSpeed, bIonBed)
            this@vsys(oParent, sName, 60);
            
            if nargin > 3
                this.fSpeed = fSpeed;
            end
            
            if nargin > 4
                this.bIonBed = bIonBed;
            end
            this.abContaminants = false(1, this.oMT.iSubstances);
            
            x=2.21/132.6; % linear aprox of the 2nd bed from the first mixed bed
            
            % We calculate the mass of Ions in the resines from literature
            % values for the different beds:
            %              Mass [g] *  Total Capacity [eq/g]        * Molar Mass
            mfResinMass(1)  = 5109e-3;
            mfResinMass(2)  = 4532e-3;
            mfResinMass(3)  = 374.6e-3;
            mfResinMass(4)  = 2840e-3;
            mfResinMass(5)  = 5109e-3*x;
            mfResinMass(6)  = 4532e-3*x;
            mfResinMass(7)  = 106e-3;
            
            % Total Capacity in [eq/kg] 
            this.mfTotalCapacity(1) = 0.8373;
            this.mfTotalCapacity(2) = 0.9273;
            this.mfTotalCapacity(3) = 2.097;
            this.mfTotalCapacity(4) = 2.353;
            this.mfTotalCapacity(5) = 0.8373;
            this.mfTotalCapacity(6) = 0.9273;
            this.mfTotalCapacity(7) = 2.097;
           
            % Define the individual ion exchange resines
            %                                                       Void Fraction     Ion Mass        Total Capacity             Volume          Cation?     Strong?     Number of Cells?     
            components.matter.WPA.subsystems.Resin(this, 'Resin_1', 0.28,             mfResinMass(1), this.mfTotalCapacity(1),   5.72e-3,        true,       true,       miCells(1));     %IRN 77 part of the mixed Bed, cations - adjusted values
            components.matter.WPA.subsystems.Resin(this, 'Resin_2', 0.28,             mfResinMass(2), this.mfTotalCapacity(2),   5.72e-3,        false,      true,       miCells(2));     %IRN 78 part of the mixed Bed, anions - adjusted values
            components.matter.WPA.subsystems.Resin(this, 'Resin_3', 0.28,             mfResinMass(3), this.mfTotalCapacity(3),   0.422e-3,       true,       true,       miCells(3));     %IRN 77, cations
            components.matter.WPA.subsystems.Resin(this, 'Resin_4', 0.29,             mfResinMass(4), this.mfTotalCapacity(4),   2.042e-3,       false,      false,      miCells(4));     %IRA 68, anions
            components.matter.WPA.subsystems.Resin(this, 'Resin_5', 0.28,             mfResinMass(5), this.mfTotalCapacity(5),   5.72e-3*x,      true,       true,       miCells(5));     %IRN 77 part of the mixed Bed, cations - adjusted values
            components.matter.WPA.subsystems.Resin(this, 'Resin_6', 0.28,             mfResinMass(6), this.mfTotalCapacity(6),   5.72e-3*x,      false,      true,       miCells(6));     %IRN 78 part of the mixed Bed, anions - adjusted values
            components.matter.WPA.subsystems.Resin(this, 'Resin_7', 0.28,             mfResinMass(7), this.mfTotalCapacity(7),   0.094e-3,       true,       true,       miCells(7));     %IRN 77, cations
            
        end
    
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Now we connect the Resin compartments among each other, we do
            % this without the setIF flow function because we do not want
            % to define so many additional IF branches, stores and phases
            % but still wanted to use the modularity provided by the
            % subsystem functionality
            for iChild = 1 : this.iChildren
                
                oFirstWaterPhaseResin = this.toChildren.(['Resin_', num2str(iChild)]).toStores.Resin.toPhases.Water_1;
                
                iCells = this.toChildren.(['Resin_', num2str(iChild)]).iCells;
                
                if iChild > 1
                    matter.branch(this, oPreviousLastWaterPhaseResin,  {}, oFirstWaterPhaseResin, ['Resin', num2str(iChild),'_Cell', num2str(iChild - 1), '_to_',  num2str(iChild)]);
                end
                
                oPreviousLastWaterPhaseResin  = this.toChildren.(['Resin_', num2str(iChild)]).toStores.Resin.toPhases.(['Water_', num2str(iCells)]);
                
                this.abContaminants = this.abContaminants | this.toChildren.(this.csChildren{iChild}).abContaminants;
            end
            
            %% organic component removal
            if ~this.bIonBed
                matter.store(this, 'OrganicRemoval', 0.01);
                oWater    = this.toStores.OrganicRemoval.createPhase('mixture', 'flow', 'Water', 'liquid', 0.005, struct('H2O', 1), 293, 1e5);
                oOrganics = matter.phases.mixture(this.toStores.OrganicRemoval,  'BigOrganics', 'liquid', struct(), 293, 1e5 );

                components.matter.WPA.components.OrganicBed_P2P(this.toStores.OrganicRemoval, 'BigOrganics_P2P', oWater, oOrganics);

                matter.branch(this, oPreviousLastWaterPhaseResin,  {}, oWater, ['Resin', num2str(iChild),'_Cell', num2str(iCells), '_to_OrganicRemoval']);
            end
        end
    
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            % Since the big organics phase is empty it would use a very
            % small time step, but since the mass change actually is not
            % relevant, we can set the limits for it to inf
            tTimeStepProperties.rMaxChange = inf;
            tTimeStepProperties.fMaxStep = inf;

            if ~this.bIonBed
                this.toStores.OrganicRemoval.toPhases.BigOrganics.setTimeStepProperties(tTimeStepProperties);
            end
            
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    tTimeStepProperties.fMaxStep = this.oParent.fTimeStep * 5;

                    oPhase.setTimeStepProperties(tTimeStepProperties);

                    tTimeStepProperties = struct();
                    tTimeStepProperties.fMaxStep = this.oParent.fTimeStep * 5;
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            this.setThermalSolvers();
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
            
            for iChild = 1 : this.iChildren
                oChild = this.toChildren.(this.csChildren{iChild});
                oStore = oChild.toStores.Resin;
                
                fRemainingCapacity = 0;
                for iCell = 1:oChild.iCells
                    fRemainingCapacity = fRemainingCapacity + sum((oStore.toPhases.(['Resin_', num2str(iCell)]).afMass(oChild.iPresaturant) ./ this.oMT.afMolarMass(oChild.iPresaturant)) .* abs(this.oMT.aiCharge(oChild.iPresaturant))) / oChild.fResinMass;
                end
                
                this.mfCurrentFillState(iChild) = 1 - fRemainingCapacity / this.mfTotalCapacity(iChild);
            end
        end
    end
end



