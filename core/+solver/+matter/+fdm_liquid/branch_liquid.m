classdef branch_liquid < solver.matter.base.branch
    %%Godunov Solver branch for compressible liquids
    %
    %this is a solver for flows in a branch containing liquids it can be
    %called using 
    %
    %solver.matter.fdm_liquid.branch_liquid(oBranch, iCells, fPressureResidual,...
    %                                fMassFlowResidual)
    %
    %If the solver becomes instable decrease the Courant Number for reduced
    %time step.
    %
    %iCells: this value sets the discretization of the branch, for
    %        example for iCells = 3 the branch will consit of three cells. 
    %        For faster speed few cells should be chosen while for accurate 
    %        result more cells are necessary. Initialised to 5 if nothing
    %        is specified. Basically the rule applies that for a larger 
    %        pressure difference a higher number of cells is required.
    %
    %fPressureResidual: sets the residual target for the pressure
    %                   difference depending on the initial pressure. 
    %                   Meaning the residual target is multiplied by the
    %                   initial pressure difference to get a target
    %                   pressure difference after which the calculation is
    %                   assumed as finished. Initialzied to 10^-5 if 
    %                   nothing is specified
    %
    %fMassFlowResidual: sets the residual target for the massflow
    %                   depending on the maximum massflow during the 
    %                   simulation. Meaning the residual target is 
    %                   multiplied by the maximum massflow that occured so
    %                   far in the simulation to get a target
    %                   massflow difference after which the calculation is
    %                   assumed to have reached a time independend stead 
    %                   state. Initialzied to 10^-10 if nothing is specified
    %
    %bDeactivateTimeStepAdaption: if set to 1 the solver will not try to
    %                             increase the courant number over the time
    %                             which results in longer simulations but 
    %                             can be necessary to get stable results 
    %                             for systems which have large pressure 
    %                             changes later on.
    %
    %if one of the two residual conditions shall not be applied for the
    %simulation the residual simply has to be set to 0
    
    %the source "Riemann Solvers and Numerical Methods for Fluid Dynamics" 
    %from E.F. Toro will be denoted as number [5]
   
    properties (SetAccess = protected, GetAccess = public)
        
        %number of Cells initialized to 5 if nothing else is specified by
        %user
        inCells = 5;
        
        %Courant Number used to calculate the timestep. For CourantNumber =
        %1 the timestep becomes maximal but sometimes a smaller timestep is
        %necessary
        fCourantNumber = 1;
        
        %residual target for pressure initialized to 10^-5 if norhting else
        %is specified by user 
        fPressureResidual = 10^-5;
        
        %residual target for mass flow initialized to 10^-10 if norhting 
        %else is specified by user 
        fMassFlowResidual = 10^-10;
        
        %the minimum mass flow during the simulation is saved in this variable
        fMassFlowMin = 'empty'; %kg/s
        
        %the mass flow of the previous timestep is saved in this variable
        fMassFlowOld = 'empty'; %kg/s
        %difference between the mass flows of the two previous time steps
        fMassFlowDiff = 'empty'; %kg/s
        
        %counter for the number of steps the mass flow difference has been
        %lower than the residual target. After a certian number is reached
        %simulation is consider finished
        iMassFlowResidualCounter = 0;
        
        iPressureResidualCounter = 0;
        
        %Counter for how often the pressure in a cell had to be averaged
        %because of an error
        iErrorCounter = 0;
        
        %the initial pressure difference
        fMaxPressureDifference = 0; %Pa
        
        %values inside the branch cells for the previous time step
        mVirtualPressureOld = 'empty';
        mVirtualInternalEnergyOld = 'empty';
        mVirtualDensityOld = 'empty';
        mFlowSpeedOld = 'empty';
        mVirtualTemperatureOld = 'empty';
        
        mPressureOld3 = 'empty';
        mPressureOld2 = 'empty';
        mPressureOld1 = 'empty';
        mPressureOld = 'empty';
        mInternalEnergyOld = 'empty';
        mDensityOld = 'empty';
        mTemperatureOld = 'empty';
        
        fFlowSpeedBoundary1Old = 0;
        fFlowSpeedBoundary2Old = 0;
        
        iTimeStepAdaption = 0;
        bStopTimeStepAdaption = 0;
        fFlowSpeedCorrection = 1;
        
        %Delta temperature in the pipes created from flow procs
        mDeltaTemperaturePipe = 'empty';
        
        %these values are not required for the calculation but can be used
        %to plot the respective values.
        fTimeStepBranch
        
    end

    methods 
        function this = branch_liquid(oBranch, iCells, fPressureResidual, fMassFlowResidual, fCourantNumber, bDeactivateCourantAdaption, fFlowSpeedCorrection)
            this@solver.matter.base.branch(oBranch);  
            
            if nargin == 2
                this.inCells = iCells;
            elseif nargin == 3
                this.inCells = iCells;
                this.fPressureResidual = fPressureResidual;
            elseif nargin == 4
                this.inCells = iCells;
                this.fPressureResidual = fPressureResidual;
                this.fMassFlowResidual = fMassFlowResidual;
            elseif nargin == 5
                this.inCells = iCells;
                this.fPressureResidual = fPressureResidual;
                this.fMassFlowResidual = fMassFlowResidual;
                this.fCourantNumber = fCourantNumber;
            elseif nargin == 6    
                this.inCells = iCells;
                this.fPressureResidual = fPressureResidual;
                this.fMassFlowResidual = fMassFlowResidual;
                this.fCourantNumber = fCourantNumber;
                this.bStopTimeStepAdaption = bDeactivateCourantAdaption;
           	elseif nargin == 7    
                this.inCells = iCells;
                this.fPressureResidual = fPressureResidual;
                this.fMassFlowResidual = fMassFlowResidual;
                this.fCourantNumber = fCourantNumber;
                this.bStopTimeStepAdaption = bDeactivateCourantAdaption;
                this.fFlowSpeedCorrection = fFlowSpeedCorrection;
            end
            
            if this.fCourantNumber <= 0 || this.fCourantNumber > 1
               error('possible range for the courant number is ]0,1]') 
            end
            
            oBranch.setOutdated();
            
        end
    end
    
    methods (Access = protected)
        
        function update(this)
            
            %% get all neccessary variables
            
            %a Temperature Reference has to be defined in order to
            %calculate the internal Energy
            fTempRef = 293;

          	%TO DO: Get from Matter Table
            fHeatCapacity = 4185; %J/(kg K)
            
            iNumberOfProcs = length(this.oBranch.aoFlowProcs);
            
            mHydrDiam = zeros(iNumberOfProcs,1);
            mHydrDiamValve = zeros(iNumberOfProcs,1);
            mHydrLength = zeros(iNumberOfProcs,1);
            mDeltaPressureComp = zeros(iNumberOfProcs,1);
            mDirectionDeltaPressureComp = zeros(iNumberOfProcs,1); 
            mMaxDeltaPressureComp = zeros(iNumberOfProcs,1); 
            mDeltaTempComp = zeros(iNumberOfProcs,1);
            mTempComp = zeros(iNumberOfProcs,1);
            
            for k = 1:iNumberOfProcs
                %checks wether the flow procs contain the properties of
                %hydraulic diameter, length or delta pressure
                metaHydrDiam = findprop(this.oBranch.aoFlowProcs(1,k), 'fHydrDiam');
                metaHydrLength = findprop(this.oBranch.aoFlowProcs(1,k), 'fHydrLength');
                metaDeltaPressure = findprop(this.oBranch.aoFlowProcs(1,k), 'fDeltaPressure');
                metaDirectionDeltaPressure = findprop(this.oBranch.aoFlowProcs(1,k), 'iDir');
                metaMaxDeltaPressure = findprop(this.oBranch.aoFlowProcs(1,k), 'fMaxDeltaP');
                metaDeltaTempComp = findprop(this.oBranch.aoFlowProcs(1,k), 'fDeltaTemp');
                metaTempComp = findprop(this.oBranch.aoFlowProcs(1,k), 'fTemp');
                
                if ~isempty(metaHydrDiam)
                    mHydrDiam(k) = [ this.oBranch.aoFlowProcs(1,k).fHydrDiam ];
                end
                if ~isempty(metaHydrLength)
                    mHydrLength(k) = [ this.oBranch.aoFlowProcs(1,k).fHydrLength ];
                end
                if ~isempty(metaHydrDiam) && mHydrLength(k) == 0
                    mHydrDiamValve(k) = [ this.oBranch.aoFlowProcs(1,k).fHydrDiam ];
                else
                    mHydrDiamValve(k) = -1;
                end
                if ~isempty(metaDeltaPressure)
                    mDeltaPressureComp(k) = [ this.oBranch.aoFlowProcs(1,k).fDeltaPressure ];
                end
                if ~isempty(metaDirectionDeltaPressure)
                    mDirectionDeltaPressureComp(k) = [ this.oBranch.aoFlowProcs(1,k).iDir ];
                end
                if ~isempty(metaMaxDeltaPressure)
                    mMaxDeltaPressureComp(k) = [ this.oBranch.aoFlowProcs(1,k).fMaxDeltaP ];
                end
                if ~isempty(metaDeltaTempComp)
                    mDeltaTempComp(k) = [ this.oBranch.aoFlowProcs(1,k).fDeltaTemp ];
                end
                if ~isempty(metaTempComp)
                    mTempComp(k) = [ this.oBranch.aoFlowProcs(1,k).fTemp ];
                end
                 
            end
            
            %get the properties at the left and right side of the branch
            [fPressureBoundary1, fTemperatureBoundary1]  = this.oBranch.coExmes{1}.getPortProperties();
            [fPressureBoundary2, fTemperatureBoundary2]  = this.oBranch.coExmes{2}.getPortProperties();
            
            fVolumeBoundary1 = this.oBranch.coExmes{1}.oPhase.fVolume;  
            fVolumeBoundary2 = this.oBranch.coExmes{2}.oPhase.fVolume; 
            fMassBoundary1 = this.oBranch.coExmes{1}.oPhase.fMass; 
            fMassBoundary2 = this.oBranch.coExmes{2}.oPhase.fMass;
            
            fFlowSpeedBoundary1 = this.fFlowSpeedBoundary1Old;
            fFlowSpeedBoundary2 = this.fFlowSpeedBoundary2Old;
            
            fDensityBoundary1 = fMassBoundary1/fVolumeBoundary1;
            fDensityBoundary2 = fMassBoundary2/fVolumeBoundary2;
            
            %if the pressure difference between the two boundaries of the
            %branch is lower than a certain threshhold the pressure is
            %averaged and the timestep can be of any size
            if this.iPressureResidualCounter == 10
                
                %fPressureBoundaryNew = (fPressureBoundary1+fPressureBoundary2)/2;
                fMassFlow = 0;
                update@solver.matter.base.branch(this, fMassFlow);
                
                for k = 1: length(this.oBranch.aoFlowProcs)
                    this.oBranch.aoFlowProcs(1,k).update();
                end
                
                this.setTimeStep(2);
                
                update@solver.matter.base.branch(this, 0);
                
            %if the counter for how often the residual target for the mass
            %flow has been undercut reaches a certain value the steady time
            %independent state is reached and the massflow
            %value from the previous timestep can be used again.
            elseif  this.iMassFlowResidualCounter == 10
                
                fTimeStep = inf;
                
                this.setTimeStep(fTimeStep);

                update@solver.matter.base.branch(this, this.fMassFlowOld);
                %TO DO: Temperature Calculation in this case?
            
            %if none of the above conditions applies it is necessary to 
            %calculate the values for the branch using the full numerical 
            %scheme    
            else

              	%%
                %if the diameter of any pipe or valve is zero the mass flow
                %is set to zero and the calculation is finished
                
                %checks wether any pipe has diameter 0
                bAbort = 0;
                for k = 1:iNumberOfProcs
                    if mHydrLength(k) ~= 0 && mHydrDiam(k) == 0
                        bAbort = 1;
                    end
                end
                
                if bAbort || length(find(mHydrDiamValve)) ~= length(mHydrDiamValve)
                    this.fMassFlowOld = 0;
                    %sets the timestep from this branch for the base branch
                    this.setTimeStep(inf);

                    %calls the update for the base branch using the newly
                    %calculated mass flow
                    %branch(this, fFlowRate, afPressures, afTemps)
                    update@solver.matter.base.branch(this, 0);
                    return
                end
                
                %minimal diameters in the system without zero elements
                %because if a relevant element has the entry zero the
                %calculation is aborted by the above conditions.
                fMinHydrDiam = min(mHydrDiam(mHydrDiam~=0));

                %%
                %fix matter values required to use the correlations for
                %density and pressure. 
                
                %TO DO make dependant on matter table
                %density at one fixed datapoint
                fFixDensity = 998.21;        %g/dm³
                %temperature for the fixed datapoint
                fFixTemperature = 293.15;           %K
                %Molar Mass of the compound
                fMolMassH2O = 18.01528;       %g/mol
                %critical temperature
                fCriticalTemperature = 647.096;         %K
                %critical pressure
                fCriticalPressure = 220.64*10^5;      %N/m² = Pa

                %boiling point normal pressure
                fBoilingPressure = 1.01325*10^5;      %N/m² = Pa
                %normal boiling point temperature
                fBoilingTemperature = 373.124;      %K
                
                %%
                %calculates the initial boundary values for the internal
                %energy
                
                %normally the flow speed also has to be taken into account
                %when calculation the internal energy. But for the stores a
                %flow speed of 0 m/s is assumed.
                %Internal Energy according to [5] page 88 equation (3.3)
                %using the equation c_p*DeltaTemp for the specific internal
                %energy
                fInternalEnergyBoundary1 = (fHeatCapacity*(fTemperatureBoundary1-fTempRef))*fDensityBoundary1;
                fInternalEnergyBoundary2 = (fHeatCapacity*(fTemperatureBoundary2-fTempRef))*fDensityBoundary2;
                
                %%
                %calculates the boundary pressures with 
                %regard to pressure influence from flow procs
                %this is not used in the calculation but is necessary to
                %make some decision (like when to abort etc) in the programm
                fPressureBoundary1WithProcs = fPressureBoundary1;
                fPressureBoundary2WithProcs = fPressureBoundary2;
                for k = 1:iNumberOfProcs
                    if mDirectionDeltaPressureComp(k) > 0
                        fPressureBoundary1WithProcs = fPressureBoundary1WithProcs + mDeltaPressureComp(k);
                    elseif mDirectionDeltaPressureComp(k) < 0
                        fPressureBoundary2WithProcs = fPressureBoundary2WithProcs + mDeltaPressureComp(k);
                    else
                        if ~strcmp(this.fMassFlowOld, 'empty') && this.fMassFlowOld > 0
                            fPressureBoundary1WithProcs = fPressureBoundary1WithProcs - mDeltaPressureComp(k);
                        elseif ~strcmp(this.fMassFlowOld, 'empty') && this.fMassFlowOld < 0
                            fPressureBoundary2WithProcs = fPressureBoundary2WithProcs - mDeltaPressureComp(k);
                        end
                    end
                end
                
                fDensityBoundary1 = solver.matter.fdm_liquid.functions.LiquidDensity(fTemperatureBoundary1,...
                       fPressureBoundary1, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                       fCriticalPressure, fBoilingPressure, fBoilingTemperature);
             	fDensityBoundary2 = solver.matter.fdm_liquid.functions.LiquidDensity(fTemperatureBoundary2,...
                       fPressureBoundary2, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                       fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                
                %%
                %sets the initial values for pressure, density, internal 
                %energy, temperature and flow speed in the cells either 
                %using the minimal boundary values or the values from the 
                %previous time step
                
                %in the first step where no values inside the cells exist
                %the cells are initialzied on the minimum boundary values
                if strcmp(this.mVirtualPressureOld,'empty')
                    
                    mVirtualInternalEnergy = zeros(this.inCells, 1);
                    mVirtualDensity = zeros(this.inCells, 1);
                    mFlowSpeed = zeros(this.inCells, 1);
                    mVirtualTemperature = zeros((this.inCells), 1);
                    mVirtualPressure = zeros((this.inCells), 1);
                    
                    for k = 1:1:(this.inCells)
                        if fTemperatureBoundary1 < fTemperatureBoundary2
                            mVirtualPressure(k,1) = fPressureBoundary1;
                            mVirtualInternalEnergy(k,1) = fInternalEnergyBoundary1;
                            mVirtualDensity(k,1) = fDensityBoundary1;
                            mVirtualTemperature(k,1) = fTemperatureBoundary1;
                        elseif (fTemperatureBoundary1 == fTemperatureBoundary2) &&(fPressureBoundary1WithProcs <= fPressureBoundary2WithProcs)
                            mVirtualPressure(k,1) = fPressureBoundary1;
                            mVirtualInternalEnergy(k,1) = fInternalEnergyBoundary1;
                            mVirtualDensity(k,1) = fDensityBoundary1;
                            mVirtualTemperature(k,1) = fTemperatureBoundary1;
                        else
                            mVirtualPressure(k,1) = fPressureBoundary2;
                            mVirtualInternalEnergy(k,1) = fInternalEnergyBoundary2;
                            mVirtualDensity(k,1) = fDensityBoundary2;
                            mVirtualTemperature(k,1) = fTemperatureBoundary2;
                        end
                    end
                else
                    %variables from the flow processors (these are vectors
                    %containing the values for each cell)
                    mVirtualPressure = this.mVirtualPressureOld; %[kg/(m*s^2)]
                    mVirtualInternalEnergy = this.mVirtualInternalEnergyOld; %internal energy [J]       
                    mVirtualDensity = this.mVirtualDensityOld; %density [kg/m³]
                    mFlowSpeed = this.mFlowSpeedOld;  %velocity [m/s]
                    mVirtualTemperature = this.mVirtualTemperatureOld; %temperature [K]
                end
                

                %%
                %calculates the cell length of the components in the branch
                %and then derives the maximum time step from the respective
                %wavespeed in a cell and the cell length
                
                %defines the cell length by dividing the whole length of the
                %pipe with the number of vells
                fCellLength = sum(mHydrLength)/this.inCells;


                %%
                %since not every component is discretized on its own it is
                %necessary to discern in which cell which component ends.
                %For a pipe having a length of 0.3m with a cell length
                %of 0.16 m the entry of mCompCellPosition would be 2
                mCompCellPosition = zeros(this.inCells, 1);
                if (~strcmp(this.fMassFlowOld, 'empty') && this.fMassFlowOld >= 0) || (fPressureBoundary1WithProcs >= fPressureBoundary2WithProcs)
                    for k = 1:length(mHydrLength)
                        mCompCellPosition(k)=ceil(sum(mHydrLength(1:k))/fCellLength);
                        if (mod(sum(mHydrLength(1:k)),fCellLength) == 0) && (mCompCellPosition(k) ~= this.inCells)
                            mCompCellPosition(k) = mCompCellPosition(k)+1;
                        end
                    end
                else
                    mCompCellPosition(1) = 1;
                    for k = 2:length(mHydrLength)
                        mCompCellPosition(k)=ceil(sum(mHydrLength(1:(k-1)))/fCellLength);
                    end
                end
                
                %mPressure contains the actuall cell values including the
                %proc pressure
                mPressureWithoutLoss = mVirtualPressure;
                mPressure = mVirtualPressure;
                mTemperature = mVirtualTemperature;
                mInternalEnergy = mVirtualInternalEnergy;
                mDensity = mVirtualDensity;
                mTotalPressureLossCell = zeros(this.inCells,1);
                for k = 1:this.inCells
                    %the actual pressure is the sum of the virtual pressure
                    %and all pressure influences from components.
                    %this adds the pressure from all active components with
                    %respect to their direction
                    mPressureWithoutLoss(k) = mVirtualPressure(k)+ abs(sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)));
                    %after that the influence of components without
                    %direction (Dir = 0) has to be calculated. 
                    mDeltaPressureCompCell = mDeltaPressureComp(mCompCellPosition == k);
                    if ~isempty(mDeltaPressureCompCell)
                        mTotalPressureLossCell(k) = sum(mDeltaPressureCompCell(mDirectionDeltaPressureComp(mCompCellPosition == k) == 0));
                    end
                    mPressure(k) = mPressureWithoutLoss(k) - mTotalPressureLossCell(k);
                   	%the actual temperatue is calculate from the sum of the
                    %virtual temperature and all temperature differences
                    %from procs
                    if sum(mDeltaTempComp(mCompCellPosition == k)) ~= 0
                        mTemperature(k) = mVirtualTemperature(k-1)+sum(mDeltaTempComp(mCompCellPosition == k));
                    else
                        mTemperature(k) = mVirtualTemperature(k);
                    end
                    %Density and internal energy are then calculate from
                    %the actual pressure and temperature
                    if mPressure(k) ~= mVirtualPressure(k) || mTemperature(k) ~= mVirtualTemperature(k)
                        mDensity(k) = solver.matter.fdm_liquid.functions.LiquidDensity(mTemperature(k),...
                            mPressure(k), fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                            fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                    else
                        mDensity(k) = mVirtualDensity(k);
                    end
                    if mTemperature(k) ~= mVirtualTemperature(k)
                        mInternalEnergy(k) = mDensity(k)*(0.5*mFlowSpeed(k)^2+fHeatCapacity*(mTemperature(k)-fTempRef));
                    else
                        mInternalEnergy(k) = mVirtualInternalEnergy(k);
                    end
                    
                end
                
                %%
                %calculates the godunov fluxes between the cells using a
                %HLLC approximate Riemann solver
                                                
%the numbering of the Godunov Fluxes "mGodunovFlux" is done according to 
%the following sketch, using the first and last entry as the flux over the
%branch boundaries. The flow direction of the fluid is not restricted and 
%can change during the calculation           
%
%       Flux 1        Flux 2      Flux 3       Flux 4     Flux 5     Flux 6
%             ___________________________________________________________
%           |           |            |           |           |           |
%           |           |            |           |           |           |
%           |   cell 1  |    cell 2  |   cell 3  |   cell 4  |   cell 5  |
%           |           |            |           |           |           |
%           |___________|____________|___________|___________|___________|
%
%in the case that several components are discretised as pipes
%the cells and fluxes simply are counted as if it was a single large
%pipe

                %preallocation of vectors
                mGodunovFlux = zeros((this.inCells)+1, 3);
                mMaxWaveSpeed = zeros((this.inCells)+1, 1);
                mPressureStar = zeros((this.inCells)+1, 1);
                
                %the overall if query checks in which direction the fluid
                %is flowing or if that has not been discerned yet which
                %side has the higher pressure
                if (~strcmp(this.fMassFlowOld, 'empty') && this.fMassFlowOld > 0) || (fPressureBoundary1WithProcs >= fPressureBoundary2WithProcs)
                    %calculates the Godunov Fluxes and wave speed estimates at the
                    %in- and outlet of the branch
                    if mCompCellPosition(1) == 1 &&  sum(mDeltaPressureComp(mCompCellPosition == 1).*mDirectionDeltaPressureComp(mCompCellPosition == 1)) < 0 
                        [mGodunovFlux(1,:), mMaxWaveSpeed(1,1), mPressureStar(1,1)] = solver.matter.fdm_liquid.functions.HLLC(fPressureBoundary1-mTotalPressureLossCell(1), fDensityBoundary1, fFlowSpeedBoundary1, fInternalEnergyBoundary1,...
                            mPressureWithoutLoss(1), mDensity(1), mFlowSpeed(1), mInternalEnergy(1), fTemperatureBoundary1, mTemperature(1));
                    else
                        [mGodunovFlux(1,:), mMaxWaveSpeed(1,1), mPressureStar(1,1)] = solver.matter.fdm_liquid.functions.HLLC(fPressureBoundary1-mTotalPressureLossCell(1), fDensityBoundary1, fFlowSpeedBoundary1, fInternalEnergyBoundary1,...
                            mVirtualPressure(1), mVirtualDensity(1), mFlowSpeed(1), mVirtualInternalEnergy(1), fTemperatureBoundary1, mVirtualTemperature(1));
                    end
                    
                    if mCompCellPosition(end) == this.inCells && sum(mDeltaPressureComp(mCompCellPosition == this.inCells).*mDirectionDeltaPressureComp(mCompCellPosition == this.inCells)) < 0
                        [mGodunovFlux((this.inCells)+1,:), mMaxWaveSpeed((this.inCells)+1, 1), mPressureStar((this.inCells)+1,1)] = ...
                        solver.matter.fdm_liquid.functions.HLLC(mVirtualPressure(this.inCells)-mTotalPressureLossCell(end), mVirtualDensity(this.inCells), mFlowSpeed(this.inCells), mVirtualInternalEnergy(this.inCells),...
                        fPressureBoundary2, fDensityBoundary2, fFlowSpeedBoundary2, fInternalEnergyBoundary2, mVirtualTemperature(end), fTemperatureBoundary2);                
                    else
                        [mGodunovFlux((this.inCells)+1,:), mMaxWaveSpeed((this.inCells)+1, 1), mPressureStar((this.inCells)+1,1)] = ...
                        solver.matter.fdm_liquid.functions.HLLC(mPressureWithoutLoss(this.inCells)-mTotalPressureLossCell(end), mDensity(this.inCells), mFlowSpeed(this.inCells), mInternalEnergy(this.inCells),...
                        fPressureBoundary2, fDensityBoundary2, fFlowSpeedBoundary2, fInternalEnergyBoundary2, mTemperature(end), fTemperatureBoundary2);                
                    end
                    
                    for k = 1:1:(this.inCells)-1
                        if (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) <= 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) >= 0)
                            [mGodunovFlux(k+1,:), mMaxWaveSpeed(k+1), mPressureStar(k+1)] = solver.matter.fdm_liquid.functions.HLLC(mVirtualPressure(k)-mTotalPressureLossCell(k), mDensity(k), mFlowSpeed(k), mInternalEnergy(k),...
                            mVirtualPressure(k+1), mVirtualDensity(k+1), mFlowSpeed(k+1), mVirtualInternalEnergy(k+1), mTemperature(k), mVirtualTemperature(k+1));
                        
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) > 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) >= 0)
                            [mGodunovFlux(k+1,:), mMaxWaveSpeed(k+1), mPressureStar(k+1)] = solver.matter.fdm_liquid.functions.HLLC(mPressureWithoutLoss(k)-mTotalPressureLossCell(k), mDensity(k), mFlowSpeed(k), mInternalEnergy(k),...
                            mVirtualPressure(k+1), mVirtualDensity(k+1), mFlowSpeed(k+1), mVirtualInternalEnergy(k+1), mTemperature(k), mVirtualTemperature(k+1));
                        
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) <= 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) < 0)
                            [mGodunovFlux(k+1,:), mMaxWaveSpeed(k+1), mPressureStar(k+1)] = solver.matter.fdm_liquid.functions.HLLC(mVirtualPressure(k)-mTotalPressureLossCell(k), mDensity(k), mFlowSpeed(k), mInternalEnergy(k),...
                            mPressureWithoutLoss(k+1), mVirtualDensity(k+1), mFlowSpeed(k+1), mVirtualInternalEnergy(k+1), mTemperature(k), mVirtualTemperature(k+1));
                        
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) > 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) < 0)
                            [mGodunovFlux(k+1,:), mMaxWaveSpeed(k+1), mPressureStar(k+1)] = solver.matter.fdm_liquid.functions.HLLC(mPressureWithoutLoss(k)-mTotalPressureLossCell(k), mDensity(k), mFlowSpeed(k), mInternalEnergy(k),...
                            mPressureWithoutLoss(k+1), mVirtualDensity(k+1), mFlowSpeed(k+1), mVirtualInternalEnergy(k+1), mTemperature(k), mVirtualTemperature(k+1));
                        else
                            error('seems like one case was forgotten here')
                        end
                    end
                %calculation for negative flow direction in the branch
                else
                    %calculates the Godunov Fluxes and wave speed estimates at the
                    %in- and outlet of the branch
                    if mCompCellPosition(1) == 1 &&  sum(mDeltaPressureComp(mCompCellPosition == 1).*mDirectionDeltaPressureComp(mCompCellPosition == 1)) > 0 
                        [mGodunovFlux(1,:), mMaxWaveSpeed(1,1), mPressureStar(1,1)] = solver.matter.fdm_liquid.functions.HLLC(fPressureBoundary1+mTotalPressureLossCell(1), fDensityBoundary1, fFlowSpeedBoundary1, fInternalEnergyBoundary1,...
                            mPressureWithoutLoss(1), mDensity(1), mFlowSpeed(1), mInternalEnergy(1), fTemperatureBoundary1, mTemperature(1));
                    else
                        [mGodunovFlux(1,:), mMaxWaveSpeed(1,1), mPressureStar(1,1)] = solver.matter.fdm_liquid.functions.HLLC(fPressureBoundary1+mTotalPressureLossCell(1), fDensityBoundary1, fFlowSpeedBoundary1, fInternalEnergyBoundary1,...
                            mVirtualPressure(1), mVirtualDensity(1), mFlowSpeed(1), mInternalEnergy(1), fTemperatureBoundary1, mTemperature(1));
                    end
                    
                    if mCompCellPosition(end) == this.inCells && sum(mDeltaPressureComp(mCompCellPosition == this.inCells).*mDirectionDeltaPressureComp(mCompCellPosition == this.inCells)) < 0
                        [mGodunovFlux((this.inCells)+1,:), mMaxWaveSpeed((this.inCells)+1, 1), mPressureStar((this.inCells)+1,1)] = ...
                        solver.matter.fdm_liquid.functions.HLLC(mVirtualPressure(this.inCells)-mTotalPressureLossCell(end), mVirtualDensity(this.inCells), mFlowSpeed(this.inCells), mVirtualInternalEnergy(this.inCells),...
                        fPressureBoundary2, fDensityBoundary2, fFlowSpeedBoundary2, fInternalEnergyBoundary2, mVirtualTemperature(end), fTemperatureBoundary2);                
                    else
                        [mGodunovFlux((this.inCells)+1,:), mMaxWaveSpeed((this.inCells)+1, 1), mPressureStar((this.inCells)+1,1)] = ...
                        solver.matter.fdm_liquid.functions.HLLC(mPressureWithoutLoss(this.inCells)-mTotalPressureLossCell(end), mDensity(this.inCells), mFlowSpeed(this.inCells), mVirtualInternalEnergy(this.inCells),...
                        fPressureBoundary2, fDensityBoundary2, fFlowSpeedBoundary2, fInternalEnergyBoundary2, mVirtualTemperature(end), fTemperatureBoundary2);                
                    end
                    
                    for k = 1:1:(this.inCells)-1
                        if (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) <= 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) >= 0)
                            [mGodunovFlux(k+1,:), mMaxWaveSpeed(k+1), mPressureStar(k+1)] = solver.matter.fdm_liquid.functions.HLLC(mVirtualPressure(k)+mTotalPressureLossCell(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k),...
                            mVirtualPressure(k+1), mDensity(k+1), mFlowSpeed(k+1), mInternalEnergy(k+1), mVirtualTemperature(k), mTemperature(k+1));
                        
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) > 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) >= 0)
                            [mGodunovFlux(k+1,:), mMaxWaveSpeed(k+1), mPressureStar(k+1)] = solver.matter.fdm_liquid.functions.HLLC(mPressureWithoutLoss(k)+mTotalPressureLossCell(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k),...
                            mVirtualPressure(k+1), mDensity(k+1), mFlowSpeed(k+1), mInternalEnergy(k+1), mVirtualTemperature(k), mTemperature(k+1));
                        
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) <= 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) < 0)
                            [mGodunovFlux(k+1,:), mMaxWaveSpeed(k+1), mPressureStar(k+1)] = solver.matter.fdm_liquid.functions.HLLC(mVirtualPressure(k)+mTotalPressureLossCell(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k),...
                            mPressureWithoutLoss(k+1), mDensity(k+1), mFlowSpeed(k+1), mInternalEnergy(k+1), mVirtualTemperature(k), mTemperature(k+1));
                        
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) > 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) < 0)
                            [mGodunovFlux(k+1,:), mMaxWaveSpeed(k+1), mPressureStar(k+1)] = solver.matter.fdm_liquid.functions.HLLC(mPressureWithoutLoss(k)+mTotalPressureLossCell(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k),...
                            mPressureWithoutLoss(k+1), mDensity(k+1), mFlowSpeed(k+1), mInternalEnergy(k+1), mVirtualTemperature(k), mTemperature(k+1));
                        else
                            error('seems like one case was forgotten here')
                        end
                    end
                end
                
                %%
                %calculates the state vectors for each cell according to [5]
                %page equation
                %each line in the matrix corresponds to one state vector with
                %the entries (Density, Density*FlowSpeed, InternalEnergy)
                mStateVector = zeros(this.inCells, 3);
                mVirtualStateVector = zeros(this.inCells, 3);

                for k = 1:1:this.inCells
                    mStateVector(k,1) = mDensity(k,1); 
                    mStateVector(k,2) = mDensity(k,1)*mFlowSpeed(k,1);
                    mStateVector(k,3) = mInternalEnergy(k,1);
                    
                    mVirtualStateVector(k,1) = mVirtualDensity(k,1); 
                    mVirtualStateVector(k,2) = mVirtualDensity(k,1)*mFlowSpeed(k,1);
                    mVirtualStateVector(k,3) = mVirtualInternalEnergy(k,1);
                end
                                
                %%
                %calculation of the boundary flow speed
                
             	%for the next time step it is necessary to save the flow 
                %speed of the fluid at the two exmes which can be gained by 
                %dividing the first entry of the Godunov Flux which is
                %Density*FlowSpeed with the Density.
                if mGodunovFlux(1,1) >= 0
                    fFlowSpeedBoundary1New = mGodunovFlux(1,1)/fDensityBoundary1;
                else
                    fFlowSpeedBoundary1New = mGodunovFlux(1,1)/mDensity(1);
                end
                if mGodunovFlux(this.inCells+1,1) >= 0
                    fFlowSpeedBoundary2New = mGodunovFlux(this.inCells+1,1)/mDensity(end);
                else
                    fFlowSpeedBoundary2New = mGodunovFlux(this.inCells+1,1)/fDensityBoundary2;
                end
                
                %%
                %calculation of boundary flow speeds and the first two
                %components of the virtual godunov fluxes
                mVirtualGodunovFlux = zeros((this.inCells+1),3);
                mGodunovFlowSpeed = zeros((this.inCells+1),1);
                
                mGodunovFlowSpeed(1) = fFlowSpeedBoundary1New;
                mGodunovFlowSpeed(end) = fFlowSpeedBoundary2New;
                
                for k = 2:this.inCells
                    if mGodunovFlux(k,1) >= 0
                        mGodunovFlowSpeed(k) = mGodunovFlux(k,1)/mDensity(k-1);
                    else
                        mGodunovFlowSpeed(k) = mGodunovFlux(k,1)/mDensity(k);
                    end
                end

                %%
                %this section will check every one hundred sim tick if it
                %is possible to increase the courant number by a certain
                %amount and still retain stable simulation. 
                
                %For some system there is a stability limit how far the 
                %courant number may be increased there in case
                %instabilities are detected the courant number is reduced a
                %bit and the adaption is stopped.
                if this.bStopTimeStepAdaption ~= 1 && (this.oBranch.oContainer.oTimer.iTick > 10000) && (this.bStopTimeStepAdaption == 0)
                    for k = 1:this.inCells
                        if ((sign(this.mPressureOld(k)-this.mPressureOld1(k)) ~= sign(this.mPressureOld1(k)-this.mPressureOld2(k))) && (sign(this.mPressureOld1(k)-this.mPressureOld2(k)) ~= sign(this.mPressureOld2(k)-this.mPressureOld3(k))) && (abs(this.mPressureOld(k)-this.mPressureOld1(k)) > this.fMaxPressureDifference*10^-5))
                            this.bStopTimeStepAdaption = 1; 
                        end
                    end
                end
                
                if this.bStopTimeStepAdaption == 0 && this.iTimeStepAdaption >= 0 && this.fCourantNumber < 0.9999 && this.oBranch.oContainer.oTimer.iTick > 10000 && mod(this.oBranch.oContainer.oTimer.iTick, 10) == 0
                    this.fCourantNumber = this.fCourantNumber*1.001;
                elseif this.bStopTimeStepAdaption == 0 && this.iTimeStepAdaption >= 0 && this.fCourantNumber >= 0.9999 && this.oBranch.oContainer.oTimer.iTick > 10000 && mod(this.oBranch.oContainer.oTimer.iTick, 10) == 0
                    this.fCourantNumber = 1;
                end
                if this.bStopTimeStepAdaption == 1
                    this.fCourantNumber = this.fCourantNumber/(1.001^100);
                    this.bStopTimeStepAdaption = 2;
                end
                
                mPressureNew = -1;
                mVirtualPressureNew = -1;
                while (min(mPressureNew) < 0 || min(mVirtualPressure) < 0)
                
                %%
                %calculation of new state vector

                %calculates the time step according to [5] page 221 
                %equation (6.17)
                fTimeStep = (this.fCourantNumber*fCellLength)/abs(max(mMaxWaveSpeed(k)));

                %calculates the new cell values according to [5] page 217 
                %equation (6.11)
                mStateVectorNew = zeros(this.inCells, 3);
                
                for k = 1:1:this.inCells 
                    mStateVectorNew(k,1) = mStateVector(k,1)+(fTimeStep/fCellLength)*(mGodunovFlux(k,1)-mGodunovFlux(k+1,1));
                    
                    % it is necessary to calculate the second component of
                    % the state vector independently from the actual godunov
                    % fluxes calculated before because the second entry for
                    % the godunov flux is rho*u^2+p which means that this
                    % flux entry is always higher after a pump which
                    % increases the pressure. Instead of the Godunov Fluxes
                    % the pressure difference over the cell, the mass
                    % flow and the godunov flow speed will be used to
                    % calculate this component.
                    %checks the flow direction of the branch
                    if (~strcmp(this.fMassFlowOld, 'empty') && this.fMassFlowOld > 0) || (fPressureBoundary1WithProcs >= fPressureBoundary2WithProcs)
                        if k == this.inCells && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) < 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k,1)*mGodunovFlowSpeed(k)- mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)+(mVirtualPressure(k)-fPressureBoundary2-mTotalPressureLossCell(k)));
                        
                        elseif k == this.inCells && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) >= 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k,1)*mGodunovFlowSpeed(k)- mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)+(mPressureWithoutLoss(k)-fPressureBoundary2-mTotalPressureLossCell(k)));
                        
                        elseif sum(mDeltaPressureComp(mCompCellPosition == k)) == 0 && sum(mDeltaPressureComp(mCompCellPosition == k+1)) == 0
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k,2)-mGodunovFlux(k+1,2));
                            
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) <= 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) >= 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k,1)*mGodunovFlowSpeed(k)- mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)+(mVirtualPressure(k)-mVirtualPressure(k+1)-mTotalPressureLossCell(k)));
                            
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) > 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) >= 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k,1)*mGodunovFlowSpeed(k)- mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)+(mPressureWithoutLoss(k)-mVirtualPressure(k+1)-mTotalPressureLossCell(k)));
                            
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) <= 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) < 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k,1)*mGodunovFlowSpeed(k)- mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)+(mVirtualPressure(k)-mPressureWithoutLoss(k+1)-mTotalPressureLossCell(k)));
                            
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) > 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k+1))) < 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k,1)*mGodunovFlowSpeed(k)- mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)+(mPressureWithoutLoss(k)-mPressureWithoutLoss(k+1)-mTotalPressureLossCell(k)));   
                        else
                            error('seems like one case was forgotten here')
                        end
                        
                    else
                        if k == 1 && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) < 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)- mGodunovFlux(k,1)*mGodunovFlowSpeed(k)+(fPressureBoundary1-mPressureWithoutLoss(k)+mTotalPressureLossCell(k)));
                        
                        elseif k == 1 && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) >= 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)- mGodunovFlux(k,1)*mGodunovFlowSpeed(k)+(fPressureBoundary1-mVirtualPressure(k)+mTotalPressureLossCell(k)));
                        
                        elseif sum(mDeltaPressureComp(mCompCellPosition == k-1)) == 0 && sum(mDeltaPressureComp(mCompCellPosition == k)) == 0
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k,2)-mGodunovFlux(k+1,2));
                            
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == (k-1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k-1))) <= 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k)).*mDirectionDeltaPressureComp(mCompCellPosition == (k))) >= 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)- mGodunovFlux(k,1)*mGodunovFlowSpeed(k)+(mVirtualPressure(k-1)-mVirtualPressure(k)+mTotalPressureLossCell(k)));
                            
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == (k-1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k-1))) > 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k)).*mDirectionDeltaPressureComp(mCompCellPosition == (k))) >= 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)- mGodunovFlux(k,1)*mGodunovFlowSpeed(k)+(mPressureWithoutLoss(k-1)-mVirtualPressure(k)+mTotalPressureLossCell(k)));
                            
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == (k-1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k-1))) <= 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k)).*mDirectionDeltaPressureComp(mCompCellPosition == (k))) < 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)- mGodunovFlux(k,1)*mGodunovFlowSpeed(k)+(mVirtualPressure(k-1)-mPressureWithoutLoss(k)+mTotalPressureLossCell(k)));
                            
                        elseif (sum(mDeltaPressureComp(mCompCellPosition == (k-1)).*mDirectionDeltaPressureComp(mCompCellPosition == (k-1))) > 0) && (sum(mDeltaPressureComp(mCompCellPosition == (k)).*mDirectionDeltaPressureComp(mCompCellPosition == (k))) < 0)
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mGodunovFlux(k+1,1)*mGodunovFlowSpeed(k+1)- mGodunovFlux(k,1)*mGodunovFlowSpeed(k)+(mPressureWithoutLoss(k-1)-mPressureWithoutLoss(k)+mTotalPressureLossCell(k)));   
                        else
                            error('seems like one case was forgotten here')
                        end
                    end
                end
                
                %%
                %calculation of new cell values for density,
                %temperature, pressure, internal energy and flow speed

                mDensityNew = zeros(this.inCells,1);
                mFlowSpeedNew = zeros(this.inCells, 1);
                mInternalEnergyNew = zeros(this.inCells,1);
                mPressureNew = zeros(this.inCells,1);
                mTemperatureNew = zeros(this.inCells,1);

                mVirtualDensityNew = zeros(this.inCells,1);
                mVirtualInternalEnergyNew = zeros(this.inCells,1);
                mVirtualPressureNew = zeros(this.inCells,1);
                mVirtualTemperatureNew = zeros(this.inCells,1);
                %calculates the flow speed, pressure, density and internal
                %energy for the cells from the state vectors according to
                %their definition from [5] page 3 equation (1.7). Note that
                %here only the one dimensional case is considered which
                %leaves the values for flow speeds (v and w ) in other 
                %direction out thus giving a vector with three entries 
                %instead of five 
                for k = 1:1:this.inCells
                    mDensityNew(k) = mStateVectorNew(k,1);
                    mFlowSpeedNew(k) = mStateVectorNew(k,2)/mStateVectorNew(k,1);
                end
                
                %%
                %reduces the flow speed in the cells to 90% of its previous
                %value. This is necessary to prevent the system from
                %oscillating for a long term because of the friction less
                %calculation
                if this.fFlowSpeedCorrection == 1
                    fTimeStepCourant1 = (fCellLength)/abs(max(mMaxWaveSpeed(k)));
                    fFactor = (fTimeStepCourant1/(1*10^-5))*0.05;
                    fFlowSpeedCorrectionFactor = 1-(fFactor*this.fCourantNumber);
                    for k = 1:this.inCells
                        mFlowSpeedNew(k) = fFlowSpeedCorrectionFactor.*mFlowSpeedNew(k);
                    end

                    %As for the cell flow speeds the flow speed at the
                    %boundaries also has to be reduced to prevent oscillations
                    %in the system
                    fFlowSpeedBoundary1New = fFlowSpeedCorrectionFactor*fFlowSpeedBoundary1New;
                    fFlowSpeedBoundary2New = fFlowSpeedCorrectionFactor*fFlowSpeedBoundary2New;
                end
                %%
                %mass flow calculation

                %vector for the mass flow which contains the individual
                %flow rates for each cell
                mMassFlow = zeros(this.inCells, 1);

                %mass flow is Density*FlowSpeed*Area and the second entry
                %of the statevector is Density*FlowSpeed which means it
                %only has to be multiplied with the Area to gain the mass
                %flow
                for k = 1:this.inCells
                    mMassFlow(k) = (pi*(fMinHydrDiam/2)^2)*mStateVectorNew(k,2);
                end

                %the actually used scalar mass flow is calculated by
                %averaging the individual cell values. This leads to small 
                %errors and can crash the solver for small tanks but is 
                %necessary in order to set a consistent flow rate over the 
                %branch in V-HAB      
                fMassFlow = sum(mMassFlow)/(this.inCells);
                
                %%
                %calculates the third entry for the state vector, the
                %internal energy
                if fFlowSpeedBoundary1New >= 0
                    mGodunovFlux(1,3) = fFlowSpeedBoundary1New*(fInternalEnergyBoundary1+fPressureBoundary1);
                    mVirtualGodunovFlux(1,3) = fFlowSpeedBoundary1New*(fInternalEnergyBoundary1+fPressureBoundary1);
                else
                    mGodunovFlux(1,3) = fFlowSpeedBoundary1New*(mInternalEnergy(1)+mPressure(1));
                    mVirtualGodunovFlux(1,3) = fFlowSpeedBoundary1New*(mVirtualInternalEnergy(1)+mVirtualPressure(1));
                end
                if fFlowSpeedBoundary2New >= 0
                    mGodunovFlux(end,3) = fFlowSpeedBoundary2New*(mInternalEnergy(end)+mPressure(end));
                    mVirtualGodunovFlux(end,3) = fFlowSpeedBoundary2New*(mVirtualInternalEnergy(end)+mVirtualPressure(end));
                else
                    mGodunovFlux(end,3) = fFlowSpeedBoundary2New*(fInternalEnergyBoundary2+fPressureBoundary2);
                    mVirtualGodunovFlux(end,3) = fFlowSpeedBoundary2New*(fInternalEnergyBoundary2+fPressureBoundary2);
                end
                
                for k = 2:this.inCells
                    if mGodunovFlux(k,1) >= 0
                        mGodunovFlux(k,3) = mGodunovFlowSpeed(k)*(mInternalEnergy(k-1)+mPressure(k-1));
                        mVirtualGodunovFlux(k,3) = mGodunovFlowSpeed(k)*(mVirtualInternalEnergy(k-1)+mVirtualPressure(k-1));
                    else
                        mGodunovFlux(k,3) = mGodunovFlowSpeed(k)*(mInternalEnergy(k)+mPressure(k));
                        mVirtualGodunovFlux(k,3) = mGodunovFlowSpeed(k)*(mVirtualInternalEnergy(k)+mVirtualPressure(k));
                    end
                end
                
                for k = 1:1:this.inCells
                    if mGodunovFlux(k,1) >= 0
                        mStateVectorNew(k,3) = mStateVector(k,3)+(fTimeStep/fCellLength)*(mGodunovFlux(k,3)-mVirtualGodunovFlux(k+1,3)); 
                    else
                        mStateVectorNew(k,3) = mStateVector(k,3)+(fTimeStep/fCellLength)*(mVirtualGodunovFlux(k,3)-mGodunovFlux(k+1,3)); 
                    end
                    mInternalEnergyNew(k) = mStateVectorNew(k,3);
                end
                %%
                %calculates the values for temperature according to [5]
                %page 88 equation (3.3) using c_p*DeltaTemp als specific
                %internal energy. 
                %Pressure is calculated using the liquid pressure
                %correlation. For more information view the function file
                for k=1:1:this.inCells
                    mTemperatureNew(k) = ((mInternalEnergyNew(k)-0.5*mDensityNew(k)*mFlowSpeedNew(k)^2)/(fHeatCapacity*mDensity(k)))+fTempRef;
                    mPressureNew(k) = solver.matter.fdm_liquid.functions.LiquidPressure(mTemperatureNew(k),...
                       mDensityNew(k), fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                       fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                end
                
                %%
                %calculation of the virtual values

                %from the fluxes the new virtual densities are calculated
                for k = 1:this.inCells
                    mVirtualDensityNew(k) = mVirtualDensity(k) + (fTimeStep/fCellLength)*(mGodunovFlux(k,1)-mGodunovFlux(k+1,1));
                end

                %with the densities and the fluxes the new virtual
                %temperatures can be calculated
                for k = 1:this.inCells
                    mVirtualTemperatureNew(k) = mTemperatureNew(k)-sum(mDeltaTempComp(mCompCellPosition==k));
                end
                
                for k = 1:this.inCells
                    mVirtualInternalEnergyNew(k) = mVirtualDensityNew(k)*(0.5*mFlowSpeed(k)^2+fHeatCapacity*(mVirtualTemperatureNew(k)-fTempRef));
                    mVirtualPressureNew(k) = solver.matter.fdm_liquid.functions.LiquidPressure(mVirtualTemperatureNew(k),...
                       mVirtualDensityNew(k), fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                       fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                end
                
                %%
                if this.iTimeStepAdaption < 0 && (min(mPressureNew) < 0 || min(mVirtualPressure) < 0)
                    string = sprintf('negative pressure occured in the solver!\n First try decreasing the Courant Number of the Branch if this does not help see list of other possible errors:\n -the number of cells for the branch is too low \n -the diameter of the pipes is large compared to the volume of a tank \n -the pressures set in the system are wrong (e.g. a pump that has a too high pressure jump)');
                    error(string)
                end
                %this section decreases the time step again if the previous
                %increase lead to negative pressures
                if (min(mPressureNew) < 0 || min(mVirtualPressure) < 0) && this.fCourantNumber ~= 1
                    this.fCourantNumber = this.fCourantNumber/1.001;
                    this.iTimeStepAdaption = -1000;
                elseif (min(mPressureNew) < 0 || min(mVirtualPressure) < 0)
                    this.fCourantNumber = 0.9999;
                    this.iTimeStepAdaption = -1000;
                end
            
                end
                
                if this.iTimeStepAdaption < 0
                    this.iTimeStepAdaption = this.iTimeStepAdaption+1;
                end

                %%
                %all necessary values for the cells are calculated. Now the
                %respective values have to be set to the flows by
                %calculation the delta pressure and delta temperature
                %between each flow
                
                afPressure = zeros(iNumberOfProcs,1);
                afTemps = zeros(iNumberOfProcs,1);
                mFlowTemp = zeros(length(this.oBranch.aoFlows),1);
                mFlowPressure = zeros(length(this.oBranch.aoFlows),1);
          
                if fMassFlow >= 0
                    mFlowTemp(1) = this.oBranch.coExmes{1, 1}.fTemperature;
                    mFlowTemp(end) = mTemperatureNew(end);
                    mFlowPressure(1) = this.oBranch.coExmes{1, 1}.fPressure;
                    mFlowPressure(end) = mPressureNew(end);
                    for k = 2:iNumberOfProcs
                        if length(mCompCellPosition(mCompCellPosition==mCompCellPosition(k))) > 1
                            mIndicesOfProcsInCell = find(mCompCellPosition==mCompCellPosition(k));
                            iActiveProcNumberInThisCell = k - (mIndicesOfProcsInCell(1)-1);
                            mDeltaTempOfProcsInThisCell = mDeltaTempComp(mIndicesOfProcsInCell);
                            mDeltaPressureOfProcsInThisCell = mDeltaPressureComp(mIndicesOfProcsInCell);
                            mDirectionDeltaPressureOfProcsInThisCell = mDirectionDeltaPressureComp(mIndicesOfProcsInCell);

                            if mCompCellPosition(k) == 1
                                mFlowTemp(k) = fTemperatureBoundary1+sum(mDeltaTempOfProcsInThisCell(1:iActiveProcNumberInThisCell-1));
                                mFlowPressure(k) = fTemperatureBoundary1+sum(mDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1).*mDirectionDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1))-sum(mDeltaPressureOfProcsInThisCell(mDirectionDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1) == 0));
                            else
                                mFlowTemp(k) = mTemperatureNew(mCompCellPosition(k)-1)+sum(mDeltaTempOfProcsInThisCell(1:iActiveProcNumberInThisCell-1));
                                mFlowPressure(k) = mPressureNew(mCompCellPosition(k)-1)+sum(mDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1).*mDirectionDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1))-sum(mDeltaPressureOfProcsInThisCell(mDirectionDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1) == 0));
                            end
                        else
                            if mCompCellPosition(k) == 1
                                mFlowTemp(k) = fTemperatureBoundary1;
                                mFlowPressure(k) = mfTemperatureBoundary1;
                            else
                                mFlowTemp(k) = mTemperatureNew(mCompCellPosition(k)-1);
                                mFlowPressure(k) = mPressureNew(mCompCellPosition(k)-1);
                            end
                        end
                    end
                else
                    mFlowTemp(1) = mTemperatureNew(1);
                    mFlowTemp(end) = this.oBranch.coExmes{2, 1}.fTemperature;
                    mFlowPressure(1) = mPressureNew(1);
                    mFlowPressure(end) = this.oBranch.coExmes{2, 1}.fPressure;
                    for k = 2:iNumberOfProcs
                        if length(mCompCellPosition(mCompCellPosition==mCompCellPosition(k))) > 1
                            mIndicesOfProcsInCell = find(mCompCellPosition==mCompCellPosition(k));
                            iActiveProcNumberInThisCell = k - (mIndicesOfProcsInCell(1)-1);
                            mDeltaTempOfProcsInThisCell = mDeltaTempComp(mIndicesOfProcsInCell);
                            mDeltaPressureOfProcsInThisCell = mDeltaPressureComp(mIndicesOfProcsInCell);
                            mDirectionDeltaPressureOfProcsInThisCell = mDirectionDeltaPressureComp(mIndicesOfProcsInCell);
                            
                            if mCompCellPosition(k) == this.inCells
                                mFlowTemp(k) = fTemperatureBoundary2-sum(mDeltaTempOfProcsInThisCell(1:iActiveProcNumberInThisCell-1));
                                mFlowPressure(k) = fTemperatureBoundary2-sum(mDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1).*mDirectionDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1))-sum(mDeltaPressureOfProcsInThisCell(mDirectionDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1) == 0));
                            else
                                mFlowTemp(k) = mTemperatureNew(mCompCellPosition(k))-sum(mDeltaTempOfProcsInThisCell(1:iActiveProcNumberInThisCell-1));
                                mFlowPressure(k) = mPressureNew(mCompCellPosition(k))-sum(mDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1).*mDirectionDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1))-sum(mDeltaPressureOfProcsInThisCell(mDirectionDeltaPressureOfProcsInThisCell(1:iActiveProcNumberInThisCell-1) == 0));
                            end
                        else
                            if mCompCellPosition(k) == this.inCells
                                mFlowTemp(k) = fTemperatureBoundary2;
                                mFlowPressure(k) = fTemperatureBoundary2;
                            else
                                mFlowTemp(k) = mTemperatureNew(mCompCellPosition(k));
                                mFlowPressure(k) = mPressureNew(mCompCellPosition(k));
                            end
                        end
                    end
                end
                
                %Positive Deltas for Pressure and Temperature mean a
                %decrease in Temperature, negative an increase!
                for k = 1:iNumberOfProcs
                    afTemps(k) = mFlowTemp(k)-mFlowTemp(k+1);
                    afPressure(k) = mFlowPressure(k)-mFlowPressure(k+1);
                end

                %%
                %sets some values as object parameters in order to decide
                %when calculation can be assumed as finished
                
                %writes values for the massflow into the object parameters
                %to decide in the next step wether further numeric
                %calculation is required
                if ~strcmp(this.fMassFlowOld, 'empty')
                    this.fMassFlowDiff = fMassFlow-this.fMassFlowOld;
                end
                
                this.fMassFlowOld = fMassFlow;
                
                if this.fMaxPressureDifference < abs(fPressureBoundary1WithProcs-fPressureBoundary2WithProcs)
                    this.fMaxPressureDifference = abs(fPressureBoundary1WithProcs-fPressureBoundary2WithProcs);
                end 
                
                %if the difference between the massflow of the two previous 
                %timesteps is less than the residual target the counter for
                %the number of times this has happened in a row is
                %increased
                if  this.fMassFlowResidual ~= 0 && ~strcmp(this.fMassFlowDiff, 'empty') && (abs(this.fMassFlowDiff) < this.fMassFlowResidual)
                    this.iMassFlowResidualCounter = this.iMassFlowResidualCounter+1;
                elseif this.iMassFlowResidualCounter ~= 0 && (abs(this.fMassFlowDiff) > this.fMassFlowResidual)
                    %resets the counter to 0 if the target is no longer
                    %reached
                    this.iMassFlowResidualCounter = 0;
                end
                
                if this.fPressureResidual ~= 0 && ~strcmp(this.fMaxPressureDifference, 'empty') && (abs(fPressureBoundary1-fPressureBoundary2) < this.fMaxPressureDifference*this.fPressureResidual)
                    this.iPressureResidualCounter = this.iPressureResidualCounter+1;
                elseif this.iPressureResidualCounter ~= 0 && (abs(fPressureBoundary1-fPressureBoundary2) > this.fMaxPressureDifference*this.fPressureResidual)
                    %resets the counter to 0 if the target is no longer
                    %reached
                    this.iPressureResidualCounter = 0;
                end
                
                %%
                %writes the newly calculated values into the object
                %parameters of this branch in order to use them in the next
                %tick
                this.mFlowSpeedOld = mFlowSpeedNew;
                this.mPressureOld3 = this.mPressureOld2;
                this.mPressureOld2 = this.mPressureOld1;
                this.mPressureOld1 = this.mPressureOld;
                this.mPressureOld = mPressureNew;
                this.mInternalEnergyOld = mInternalEnergyNew;
                this.mDensityOld = mDensityNew;
                
                this.fFlowSpeedBoundary1Old = fFlowSpeedBoundary1New;
                this.fFlowSpeedBoundary2Old = fFlowSpeedBoundary2New;
                
                this.mVirtualInternalEnergyOld = mVirtualInternalEnergyNew;
                this.mVirtualDensityOld = mVirtualDensityNew;
                this.mVirtualPressureOld = mVirtualPressureNew;
                
                %%
                %this is only here to make plotting of the parameters in
                %the liquid branch possible
                this.fTimeStepBranch = fTimeStep;
                this.mTemperatureOld = mTemperatureNew;
                this.mVirtualTemperatureOld = mVirtualTemperatureNew;
                for k = 1:length(this.oBranch.oContainer.aoBranches)
                    if strcmp(this.oBranch.sName, this.oBranch.oContainer.aoBranches(k).sName)
                        this.oBranch.oContainer.aoLiquidBranch{k} = this;
                    end
                end
                
                %finnaly sets the time step for the branch as well as the
                %mass flow rate
                
                %sets the timestep from this branch for the base branch
                this.setTimeStep(fTimeStep);
                
                %tells the stores when to update
                this.oBranch.coExmes{1, 1}.oPhase.oStore.setNextExec(this.oBranch.oContainer.oTimer.fTime+fTimeStep);
                this.oBranch.coExmes{2, 1}.oPhase.oStore.setNextExec(this.oBranch.oContainer.oTimer.fTime+fTimeStep);
                %calls the update for the base branch using the newly
                %calculated mass flow
                %branch(this, fFlowRate, afPressures, afTemps)
                update@solver.matter.base.branch(this, fMassFlow, afPressure, afTemps);
                
                for k = 1: length(this.oBranch.aoFlowProcs)
                    this.oBranch.aoFlowProcs(1,k).update();
                end
                
            end

            
        end
    end
 
end