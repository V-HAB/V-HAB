classdef branch_liquid < solver.matter.base.branch
    %%Godunov Solver branch for compressible liquids
    %
    %this is a solver for flows in a branch containing liquids it can be
    %called using 
    %
    %solver.matter.fdm_liquid.branch_liquid(oBranch, iCells, fPressureResidual,...
    %                                fMassFlowResidual)
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
    %if one of the two residual conditions shall not be applied for the
    %simulation the residual simply has to be set to 0
    
    %the source "Riemann Solvers and Numerical Methods for Fluid Dynamics" 
    %from E.F. Toro will be denoted as number [5]
   
    properties (SetAccess = protected, GetAccess = public)
        
        %number of Cells initialized to 5 if nothing else is specified by
        %user
        inCells = 5;
        
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
        fInitialPressureDifference = 'empty'; %Pa
        
        %values inside the branch cells for the previous time step
        mPressureOld = 'empty';
        mInternalEnergyOld = 'empty';
        mDensityOld = 'empty';
        mFlowSpeedOld = 'empty';
        
        %Delta temperature in the pipes created from flow procs
        mDeltaTemperaturePipe = 'empty';
        
        
    end

    methods 
        function this = branch_liquid(oBranch, iCells, fPressureResidual, fMassFlowResidual)
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
            end
            
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
            
            for k = 1:iNumberOfProcs
                %checks wether the flow procs contain the properties of
                %hydraulic diameter, length or delta pressure
                metaHydrDiam = findprop(this.oBranch.aoFlowProcs(1,k), 'fHydrDiam');
                metaHydrLength = findprop(this.oBranch.aoFlowProcs(1,k), 'fHydrLength');
                metaDeltaPressure = findprop(this.oBranch.aoFlowProcs(1,k), 'fDeltaPressure');
                metaDirectionDeltaPressure = findprop(this.oBranch.aoFlowProcs(1,k), 'iDir');
                metaMaxDeltaPressure = findprop(this.oBranch.aoFlowProcs(1,k), 'fMaxDeltaP');
                metaDeltaTempComp = findprop(this.oBranch.aoFlowProcs(1,k), 'fDeltaTemp');
                
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
                 
            end
            
            %get the properties at the left and right side of the branch
            [fPressureBoundary1, fTemperatureBoundary1, fFlowSpeedBoundary1, fLiquidLevel1Old, fAcceleration1]  = ...
                this.oBranch.coExmes{1}.getPortProperties();
            [fPressureBoundary2, fTemperatureBoundary2, fFlowSpeedBoundary2, fLiquidLevel2Old, fAcceleration2]  = ...
                this.oBranch.coExmes{2}.getPortProperties();
            
            fVolumeBoundary1 = this.oBranch.coExmes{1}.oPhase.fVolume;  
            fVolumeBoundary2 = this.oBranch.coExmes{2}.oPhase.fVolume; 
            fMassBoundary1 = this.oBranch.coExmes{1}.oPhase.fMass; 
            fMassBoundary2 = this.oBranch.coExmes{2}.oPhase.fMass; 
            
            fDensityBoundary1 = fMassBoundary1/fVolumeBoundary1;
            fDensityBoundary2 = fMassBoundary2/fVolumeBoundary2;
            
            %if the pressure difference between the two boundaries of the
            %branch is lower than a certain threshhold the pressure is
            %averaged and the timestep can be of any size
            if this.iPressureResidualCounter == 10
                
                fPressureBoundaryNew = (fPressureBoundary1+fPressureBoundary2)/2;
                this.oBranch.coExmes{1}.setPortProperties(fPressureBoundaryNew, fTemperatureBoundary1, 0);
                this.oBranch.coExmes{2}.setPortProperties(fPressureBoundaryNew, fTemperatureBoundary2, 0);

                this.setTimeStep(2);
                
                update@solver.matter.base.branch(this, 0);
                
            %if the counter for how often the residual target for the mass
            %flow has been undercut reaches a certain value the steady time
            %independent state is reached and the massflow
            %value from the previous timestep can be used again.
            elseif  this.iMassFlowResidualCounter == 10
                
                fTimeStep = inf;
                
                this.setTimeStep(fTimeStep);
                
                %TO DO: Add calculation of Temperature in Pipes?
                if this.fMassFlowOld >= 0
                    fTemperatureBoundary2New = fTemperatureBoundary2 + (fTimeStep*this.fMassFlowOld*fHeatCapacity)/(fMassBoundary2*fHeatCapacity)*((fTemperatureBoundary1+sum(mDeltaTempComp))-fTemperatureBoundary2);
                    fTemperatureBoundary1New = fTemperatureBoundary1;
                else
                    fTemperatureBoundary1New = fTemperatureBoundary1 + (fTimeStep*this.fMassFlowOld*fHeatCapacity)/(fMassBoundary1*fHeatCapacity)*((fTemperatureBoundary2+sum(mDeltaTempComp))-fTemperatureBoundary1);
                    fTemperatureBoundary2New = fTemperatureBoundary2;
                end
                
                %setPortProperties(this, fPortPressure, fPortTemperature, fFlowSpeed, fLiquidLevel, fAcceleration, fDensity)
                this.oBranch.coExmes{1}.setPortProperties(fPressureBoundary1, fTemperatureBoundary1New, fFlowSpeedBoundary1, fLiquidLevel1Old, fAcceleration1, fDensityBoundary1);
                this.oBranch.coExmes{2}.setPortProperties(fPressureBoundary2, fTemperatureBoundary2New, fFlowSpeedBoundary2, fLiquidLevel2Old, fAcceleration2, fDensityBoundary2);

                update@solver.matter.base.branch(this, this.fMassFlowOld);
            
            %if none of the above conditions applies it is necessary to 
            %calculate the values for the branch using the full numerical 
            %scheme    
            else

              	%%
                %if the diameter of any pipe or valve is zero the mass flow
                %is set to zero and the calculation is finished
                iNotZeroHydrLength = find(mHydrLength);
                iNotZeroHydrDiam = find(mHydrDiam);
                
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

                fInternalEnergyBoundary1 = fHeatCapacity*(fTemperatureBoundary1-fTempRef)*fDensityBoundary1;
                fInternalEnergyBoundary2 = fHeatCapacity*(fTemperatureBoundary2-fTempRef)*fDensityBoundary2;

                %gets the number of pipes or more accuratly the number of
                %components which have a HydrLength and should
                %be treated like pipes in the discretisation
                iNumberOfPipes = length(mHydrLength)-sum(mHydrLength == 0); 
                
                %%
                %calculates the boundary pressures and densities with 
                %regard to pressure influence from flow procs
                
                %assigning the pressure difference of the flow procs
                %directly to the cells leads to wrong results since some 
                %cells in the middle of the branch will have a higher
                %pressure than their neighbours in both directions.
                %Therefore the pressure difference from procs is applied to
                %the boundaries instead
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
                
                fDensityBoundary1WithProcs = solver.matter.fdm_liquid.functions.LiquidDensity(fTemperatureBoundary1,...
                       fPressureBoundary1WithProcs, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                       fCriticalPressure, fBoilingPressure, fBoilingTemperature);
             	fDensityBoundary2WithProcs = solver.matter.fdm_liquid.functions.LiquidDensity(fTemperatureBoundary2,...
                       fPressureBoundary2WithProcs, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                       fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                 
                %%
                %sets the initial values for pressure, density, internal 
                %energy, temperature and flow speed in the cells either 
                %using the minimal boundary values or the values from the 
                %previous time step
                
                %in the first step where no values inside the cells exist
                %the cells are initialzied on the minimum boundary values
                if strcmp(this.mPressureOld,'empty')
                    
                    mPressure = zeros(this.inCells*iNumberOfPipes, 1);
                    mInternalEnergy = zeros(this.inCells*iNumberOfPipes, 1);
                    mDensity = zeros(this.inCells*iNumberOfPipes, 1);
                    mFlowSpeed = zeros(this.inCells*iNumberOfPipes, 1);
                    
                    for k = 1:1:(this.inCells*iNumberOfPipes)
                        mPressure(k,1) = min(fPressureBoundary1WithProcs, fPressureBoundary2WithProcs);
                        mInternalEnergy(k,1) = min(fInternalEnergyBoundary1, fInternalEnergyBoundary2);
                        mDensity(k,1) = min(fDensityBoundary1WithProcs, fDensityBoundary2WithProcs);
                    end
                    
                else
                    %variables from the flow processors (these are vectors
                    %containing the values for each cell)
                    mPressure = this.mPressureOld; %pressure [kg/(m*s^2)]
                    mInternalEnergy = this.mInternalEnergyOld; %internal energy [J]       
                    mDensity = this.mDensityOld; %density [kg/m³]
                    mFlowSpeed = this.mFlowSpeedOld;  %velocity [m/s]
                end
                
                mTemperature = zeros((this.inCells*iNumberOfPipes), 1);
                for k = 1:this.inCells*iNumberOfPipes
                    mTemperature(k,1) = (mInternalEnergy(k,1)/(fHeatCapacity*mDensity(k,1)))+fTempRef;
                end
               
                %calculates the state vectors for each cell according to [5]
                %page equation
                %each line in the matrix corresponds to one state vector with
                %the entries (Density, Density*FlowSpeed, InternalEnergy)
                mStateVector = zeros(this.inCells*iNumberOfPipes, 3);

                for k = 1:1:this.inCells*iNumberOfPipes
                    mStateVector(k,1) = mDensity(k,1); 
                    mStateVector(k,2) = mDensity(k,1)*mFlowSpeed(k,1);
                    mStateVector(k,3) = mInternalEnergy(k,1);
                end
                
                %%
                %calculates the godunov fluxes between the cells using a
                %HLLC approximate Riemann solver
                
                %preallocation of vectors
                mGodunovFlux = zeros((this.inCells*iNumberOfPipes)+1, 3);
                mMaxWaveSpeed = zeros((this.inCells*iNumberOfPipes)+1, 1);
                mPressureStar = zeros((this.inCells*iNumberOfPipes)+1, 1);

                %calculates the Godunov Fluxes and wave speed estimates at the
                %in- and outlet of the branch
                [mGodunovFlux(1,:), mMaxWaveSpeed(1,1), mPressureStar(1,1)] = solver.matter.fdm_liquid.functions.HLLC(fPressureBoundary1WithProcs, fDensityBoundary1WithProcs, fFlowSpeedBoundary1, fInternalEnergyBoundary1,...
                    mPressure(1), mDensity(1), mFlowSpeed(1), mInternalEnergy(1), fTemperatureBoundary1, mTemperature(1));
                [mGodunovFlux((this.inCells*iNumberOfPipes)+1,:), mMaxWaveSpeed((this.inCells*iNumberOfPipes)+1, 1), mPressureStar((this.inCells*iNumberOfPipes)+1,1)] = ...
                        solver.matter.fdm_liquid.functions.HLLC(mPressure(this.inCells*iNumberOfPipes), mDensity(this.inCells*iNumberOfPipes), mFlowSpeed(this.inCells*iNumberOfPipes), mInternalEnergy(this.inCells*iNumberOfPipes),...
                        fPressureBoundary2WithProcs, fDensityBoundary2WithProcs, fFlowSpeedBoundary2, fInternalEnergyBoundary2, mTemperature(end), fTemperatureBoundary2);
                
                %calculates the solution of the Riemann Problem and returns
                %the required Godunov fluxes for each cell boundary and the 
                %maximum wave speed estimates.
                for k = 1:1:((this.inCells)*iNumberOfPipes)-1 
                    
                    [mGodunovFlux(k+1,:), mMaxWaveSpeed(k+1), mPressureStar(k+1)] = solver.matter.fdm_liquid.functions.HLLC(mPressure(k), mDensity(k), mFlowSpeed(k), mInternalEnergy(k),...
                    mPressure(k+1), mDensity(k+1), mFlowSpeed(k+1), mInternalEnergy(k+1), mTemperature(k), mTemperature(k+1));
                   
                end

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

                %%
                %calculates the cell length of the components in the branch
                %and then derives the maximum time step from the respective
                %wavespeed in a cell and the cell length
                
                %defines the cell length by dividing the whole length of the
                %pipe with the number of vells
                mCellLength = zeros(iNumberOfProcs, 1);
                for k = 1:iNumberOfProcs
                    mCellLength(k) = mHydrLength(k)/this.inCells;
                end
                %delets all zeros from the cell length vector
                mCellLength = mCellLength(mCellLength~=0);
                
                %Sets the Courant Number for the maximum allowable time step
                CourantNumber = 1;
                
                fTimeStep = 1000;

                %calculates the time step according to [5] page equation
                n = 1;
                for k = 1:this.inCells*iNumberOfPipes
                    %TO DO Check Conditions on this if check
                    if mMaxWaveSpeed(k) >= 0 && mod(k,this.inCells) == 0 && k ~= this.inCells*iNumberOfPipes
                        fTimeStepTemp = (CourantNumber*mCellLength(n+1))/abs(mMaxWaveSpeed(k));
                    elseif mod(k,this.inCells) ~= 0 || ( mMaxWaveSpeed(k) < 0 && mod(k,this.inCells) == 0)
                        fTimeStepTemp = (CourantNumber*mCellLength(n))/abs(mMaxWaveSpeed(k));
                    end
                    
                    if fTimeStepTemp < fTimeStep
                        fTimeStep = fTimeStepTemp;
                    end
                    
                    if mod(k,this.inCells) == 0
                        n = n+1;
                    end
                end
                
                %%
                %calculation of new state vector

                %calculates the new cell values according to [5] page equation
                mStateVectorNew = zeros(this.inCells*iNumberOfPipes, 3);
                %counter for the pipes
                n = 1;
                for k = 1:1:this.inCells*iNumberOfPipes 
                    
                    %TO DO:
                    %the case of only one cell per pipe has to be
                    %considered specially
                    if this.inCells == 1
                        error('1 cell calculation not implemented yet')
                   
                    else
                       
                        %calculation for the first entry of the state vector
                        %check if first cell has a valve to the left
                        if k == 1 && mHydrDiamValve(1) ~= -1 && mGodunovFlux(k,1) >= 0
                            mStateVectorNew(k,1) = mStateVector(k,1)+...
                                (((fTimeStep*((mHydrDiamValve(1)/2)^2))/((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n))*mGodunovFlux(k,1))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,1));
                        %the case of no valve at right boundary and negative 
                        %flow speed are identival in the calculation
                        elseif k == 1
                            mStateVectorNew(k,1) = mStateVector(k,1)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,1))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,1));
                        %check if last cell has a valve to the right
                        elseif k == this.inCells*iNumberOfPipes && mHydrDiamValve(end) ~= -1 && mGodunovFlux(k+1,1) < 0
                            mStateVectorNew(k,1) = mStateVector(k,1)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,1))...
                                -(((fTimeStep*((mHydrDiamValve(end)/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k+1,1));
                        %the case of no valve at right boundary and negative 
                        %flow speed are identival in the calculation
                        elseif k == this.inCells*iNumberOfPipes
                            mStateVectorNew(k,1) = mStateVector(k,1)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,1))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,1));
                        %if the start of the next pipe is reached and the flow
                        %is positive use diameter of previous pipe with volume of 
                        %new pipe (no valve between)    
                        elseif mod(k, this.inCells) == 1 && mGodunovFlux(k,1) >= 0 && mHydrDiamValve(iNotZeroHydrLength(n)-1) == -1
                            mStateVectorNew(k,1) = mStateVector(k,1)+...
                                (((fTimeStep*(mHydrDiam(iNotZeroHydrLength(n-1))/2)^2)/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k,1))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,1));
                        %if the end of this pipe is reached and the flow is
                        %negative use diameter of next pipe with volume of this
                        %pipe (no valve between)
                        elseif mod(k, this.inCells) == 0 && mGodunovFlux(k+1,1) < 0 && mHydrDiamValve(iNotZeroHydrLength(n)+1) == -1
                            mStateVectorNew(k,1) = mStateVector(k,1)+...
                            ((fTimeStep/mCellLength(n))*mGodunovFlux(k,1))...
                            -(((fTimeStep*(mHydrDiam(iNotZeroHydrLength(n+1))/2)^2)/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k+1,1));
                        %if the start of the next pipe is reached, the flow
                        %is positive and a valve is in between use diameter of
                        %valve
                        elseif mod(k, this.inCells) == 1 && mGodunovFlux(k,1) >= 0 && mHydrDiamValve(iNotZeroHydrLength(n)-1) ~= -1
                            mStateVectorNew(k,1) = mStateVector(k,1)+...
                                (((fTimeStep*((mHydrDiamValve(iNotZeroHydrLength(n)-1))/2)^2)/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k,1))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,1));
                        %if the end of this pipe is reached, the flow is
                        %negative and a valve is in between use diameter of
                        %valve 
                        elseif mod(k, this.inCells) == 0 && mGodunovFlux(k+1,1) < 0 && mHydrDiamValve(iNotZeroHydrLength(n)+1) ~= -1
                            mStateVectorNew(k,1) = mStateVector(k,1)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,1))...
                                -(((fTimeStep*((mHydrDiamValve(iNotZeroHydrLength(n)+1)/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k+1,1));
                        %case of any non start/end of pipe cell. Here the diameter 
                        %has no influence since it is identical for both cells  
                        else
                            mStateVectorNew(k,1) = mStateVector(k,1)+(fTimeStep/mCellLength(n))*(mGodunovFlux(k,1)-mGodunovFlux(k+1,1));
                        end

                       
                        %calculation for the second entry of the state vector
                        %check if first cell has a valve to the left
                        if k == 1 && mHydrDiamValve(1) ~= -1 && mGodunovFlux(k,2) >= 0
                            mStateVectorNew(k,2) = mStateVector(k,2)+...
                                (((fTimeStep*((mHydrDiamValve(1)/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k,2))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,2));
                        %the case of no valve at right boundary and negative 
                        %flow speed are identival in the calculation
                        elseif k == 1
                            mStateVectorNew(k,2) = mStateVector(k,2)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,2))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,2));
                        %check if last cell has a valve to the right
                        elseif k == this.inCells*iNumberOfPipes && mHydrDiamValve(end) ~= -1 && mGodunovFlux(k+1,2) < 0
                            mStateVectorNew(k,2) = mStateVector(k,2)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,2))...
                                -(((fTimeStep*((mHydrDiamValve(end)/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k+1,2));
                        %the case of no valve at right boundary and negative 
                        %flow speed are identival in the calculation
                        elseif k == this.inCells*iNumberOfPipes
                            mStateVectorNew(k,2) = mStateVector(k,2)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,2))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,2));
                        %if the start of the next pipe is reached and the flow
                        %is positive use diameter of previous pipe with volume of 
                        %new pipe (no valve between)    
                        elseif mod(k, this.inCells) == 1 && mGodunovFlux(k,2) >= 0 && mHydrDiamValve(iNotZeroHydrLength(n)-1) == -1
                            mStateVectorNew(k,2) = mStateVector(k,2)+...
                                (((fTimeStep*((mHydrDiam(iNotZeroHydrLength(n-1))/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k,2))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,2));
                        %if the end of this pipe is reached and the flow is
                        %negative use diameter of next pipe with volume of this
                        %pipe (no valve between)
                        elseif mod(k, this.inCells) == 0 && mGodunovFlux(k+1,2) < 0 && mHydrDiamValve(iNotZeroHydrLength(n)+1) == -1
                            mStateVectorNew(k,2) = mStateVector(k,2)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,2))...
                                -(((fTimeStep*((mHydrDiam(iNotZeroHydrLength(n+1))/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k+1,2));
                        %if the start of the next pipe is reached, the flow
                        %is positive and a valve is in between use diameter of
                        %valve
                        elseif mod(k, this.inCells) == 1 && mGodunovFlux(k,2) >= 0 && mHydrDiamValve(iNotZeroHydrLength(n)-1) ~= -1
                            mStateVectorNew(k,2) = mStateVector(k,2)+...
                                (((fTimeStep*((mHydrDiamValve(iNotZeroHydrLength(n)-1)/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k,2))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,2));
                        %if the end of this pipe is reached, the flow is
                        %negative and a valve is in between use diameter of
                        %valve 
                        elseif mod(k, this.inCells) == 0 && mGodunovFlux(k+1,2) < 0 && mHydrDiamValve(iNotZeroHydrLength(n)+1) ~= -1
                            mStateVectorNew(k,2) = mStateVector(k,2)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,2))...
                                -(((fTimeStep*((mHydrDiamValve(iNotZeroHydrLength(n)+1)/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k+1,2));
                        %case of any non start/end of pipe cell. Here the diameter 
                        %has no influence since it is identical for both cells  
                        else
                            mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/mCellLength(n))*(mGodunovFlux(k,2)-mGodunovFlux(k+1,2));
                        end
                        
                        
                        %calculation for the third entry of the state vector
                        %check if first cell has a valve to the left
                        if k == 1 && mHydrDiamValve(1) ~= -1 && mGodunovFlux(k,3) >= 0
                            mStateVectorNew(k,3) = mStateVector(k,3)+...
                                (((fTimeStep*((mHydrDiamValve(1)/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k,3))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,3));
                        %the case of no valve at right boundary and negative 
                        %flow speed are identival in the calculation
                        elseif k == 1
                            mStateVectorNew(k,3) = mStateVector(k,3)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,3))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,3));
                        %check if last cell has a valve to the right
                        elseif k == this.inCells*iNumberOfPipes && mHydrDiamValve(end) ~= -1 && mGodunovFlux(k+1,3) < 0
                            mStateVectorNew(k,3) = mStateVector(k,3)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,3))...
                                -(((fTimeStep*((mHydrDiamValve(end)/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k+1,3));
                        %the case of no valve at right boundary and negative 
                        %flow speed are identival in the calculation
                        elseif k == this.inCells*iNumberOfPipes
                            mStateVectorNew(k,3) = mStateVector(k,3)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,3))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,3));
                        %if the start of the next pipe is reached and the flow
                        %is positive use diameter of previous pipe with volume of 
                        %new pipe (no valve between)    
                        elseif mod(k, this.inCells) == 1 && mGodunovFlux(k,3) >= 0 && mHydrDiamValve(iNotZeroHydrLength(n)-1) == -1
                            mStateVectorNew(k,3) = mStateVector(k,3)+...
                                (((fTimeStep*((mHydrDiam(iNotZeroHydrLength(n-1))/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k,3))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,3));
                        %if the end of this pipe is reached and the flow is
                        %negative use diameter of next pipe with volume of this
                        %pipe (no valve between)
                        elseif mod(k, this.inCells) == 0 && mGodunovFlux(k+1,3) < 0 && mHydrDiamValve(iNotZeroHydrLength(n)+1) == -1
                            mStateVectorNew(k,3) = mStateVector(k,3)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,3))...
                                -(((fTimeStep*((mHydrDiam(iNotZeroHydrLength(n+1))/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k+1,3));
                        %if the start of the next pipe is reached, the flow
                        %is positive and a valve is in between use diameter of
                        %valve
                        elseif mod(k, this.inCells) == 1 && mGodunovFlux(k,3) >= 0 && mHydrDiamValve(iNotZeroHydrLength(n)-1) ~= -1
                            mStateVectorNew(k,3) = mStateVector(k,3)+...
                                (((fTimeStep*((mHydrDiamValve(iNotZeroHydrLength(n)-1)/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k,3))...
                                -((fTimeStep/mCellLength(n))*mGodunovFlux(k+1,3));
                        %if the end of this pipe is reached, the flow is
                        %negative and a valve is in between use diameter of
                        %valve 
                        elseif mod(k, this.inCells) == 0 && mGodunovFlux(k+1,3) < 0 && mHydrDiamValve(iNotZeroHydrLength(n)+1) ~= -1
                            mStateVectorNew(k,3) = mStateVector(k,3)+...
                                ((fTimeStep/mCellLength(n))*mGodunovFlux(k,3))...
                                -(((fTimeStep*((mHydrDiamValve(iNotZeroHydrLength(n)+1)/2)^2))/(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)*mCellLength(n)))*mGodunovFlux(k+1,3));
                        %case of any non start/end of pipe cell. Here the diameter 
                        %has no influence since it is identical for both cells  
                        else
                            mStateVectorNew(k,3) = mStateVector(k,3)+(fTimeStep/mCellLength(n))*(mGodunovFlux(k,3)-mGodunovFlux(k+1,3));
                        end
                    end
       
                    if mod(k,this.inCells) == 0
                        n = n+1;
                    end
                    
                end
                
                
                %%
                %calculation of new cell values for density,
                %temperature, pressure, internal energy and flow speed
                
                mDensityNew = zeros(this.inCells*iNumberOfPipes,1);
                mFlowSpeedNew = zeros(this.inCells*iNumberOfPipes, 1);
                mInternalEnergyNew = zeros(this.inCells*iNumberOfPipes,1);
                mPressureNew = zeros(this.inCells*iNumberOfPipes,1);
                mTemperatureNew = zeros(this.inCells*iNumberOfPipes,1);
                %calculates the flow speed, pressure, density and internal
                %energy for the cells from the state vectors
                for k = 1:1:this.inCells*iNumberOfPipes
                    mDensityNew(k) = mStateVectorNew(k,1);
                    mFlowSpeedNew(k) = mStateVectorNew(k,2)/mStateVectorNew(k,1);
                    mInternalEnergyNew(k) = mStateVectorNew(k,3);
                end           

                for k=1:1:this.inCells*iNumberOfPipes
                   mTemperatureNew(k) = (mInternalEnergyNew(k)/(fHeatCapacity*mDensity(k)))+fTempRef;
                   mPressureNew(k) = solver.matter.fdm_liquid.functions.LiquidPressure(mTemperatureNew(k),...
                       mDensityNew(k), fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                       fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                end
                
                %%
                %friction calculation for cell values
  
                %TO DO: Get from Matter Table
                fDynamicViscosity = 1001.6*10^-6; %kg/(m s)
                
                %calculates the pressure loss in the cells of the pipe
%                 mDeltaPressure = zeros(this.inCells*iNumberOfPipes, 1);
                mRe = zeros(this.inCells*iNumberOfPipes, 1);
                n = 1;
                 for k = 1:this.inCells*iNumberOfPipes
%                     mDeltaPressure(k) = solver.matter.fdm_liquid.functions.pressure_loss_pipe(mHydrDiam(n), mHydrLength(n),...
%                             mFlowSpeedNew(k), fDynamicViscosity, mDensityNew(k), 0);
%                         
%                     mPressureNew(k) = mPressureNew(k)-abs(mDeltaPressure(k));
%                     
                    mRe(k) = (mFlowSpeed(k) * mHydrDiam(n))/(fDynamicViscosity/mDensity(k));
                    
                  	if mod(k,this.inCells) == 0 
                        while mHydrLength(n) == 0
                            n = n+1;
                        end
                    end
                end
                
                %TO DO: no good equation found for the friction influence 
                %on flow speed found.
                %However only with the pressure loss and no loss
                %in flow speed the system oscillates for a long time.
                %For a factor >= 0.99 a small oscillation is still present
                %according to literature (Dubbel) the average flow speed in
                %laminar case is 0.5*vmax and in turbulent case it is about
                %0.84*vmax so these values will be used atm        
                for k = 1:this.inCells*iNumberOfPipes
                    if mRe(k) <= 2320
                        mFlowSpeedNew(k) = 0.5*mFlowSpeedNew(k);
                    else
                        mFlowSpeedNew(k) = 0.84*mFlowSpeedNew(k);
                    end
                end
                
                %%
                %mass flow calculation

                %vector for the mass flow which contains the individual
                %flow rates for each cell
                mMassFlow = zeros(this.inCells*iNumberOfPipes, 1);

                n=1;
                m=1;
                for k = 1:this.inCells*iNumberOfPipes
                    mMassFlow(k) = (pi*(mHydrDiam(n)/2)^2)*mStateVectorNew(k,2);
                    if mod(k,this.inCells) == 0 && k ~= this.inCells*iNumberOfPipes
                        n = iNotZeroHydrLength(m+1);
                        m = m+1;
                    end
                end
                
                %the actually used scalar mass flow is calculated by
                %averaging the individual cell values      
                fMassFlow = sum(mMassFlow)/(this.inCells*iNumberOfPipes);

                %calculates the exact values for the mass flow at both boundaries
                %in order to compare them to the averaged mass flow. In
                %case that a valve is placed directly at a tank this is
                %necessary to limit the mass flow
%                 if ((mHydrDiamValve(1)/2)^2) ~= -1 && mGodunovFlux(1,1) < 0
%                     fMassFlowBoundary1Exact = ((pi*(mHydrDiam(1)/2)^2)/fVolumeBoundary1)*(0-mGodunovFlux(1,1));
%                     if fMassFlow > fMassFlowBoundary1Exact
%                         fMassFlow = fMassFlowBoundary1Exact;
%                     end
%                 end
%                 if ((mHydrDiamValve(end)/2)^2) ~= -1 && mGodunovFlux(end,1) >= 0
%                     fMassFlowBoundary2Exact = ((pi*(mHydrDiam(1)/2)^2)/fVolumeBoundary1)*(0-mGodunovFlux(1,1));
%                     if fMassFlow > fMassFlowBoundary2Exact
%                         fMassFlow = fMassFlowBoundary2Exact;
%                     end
%                 end
                
                %%
                %calculation of new boundary values for mass, density, 
                %internal energy and temperature (without flow proc
                %influence)
                
                %the new masses in the phases at each boundary are
                %calculated in order to then calculate the density and
                %pressure from this value
                fMassBoundary1New = fMassBoundary1 - fTimeStep*fMassFlow;
                fMassBoundary2New = fMassBoundary2 + fTimeStep*fMassFlow;
     
                %new values for the densities are calculated
                fDensityBoundary1New = fMassBoundary1New/fVolumeBoundary1;
                fDensityBoundary2New = fMassBoundary2New/fVolumeBoundary2;
                
                %the new internal energy values of the boundary phases are
                %calculated from the internal energy flows at each side of
                %the branch
                fInternalEnergyBoundary1New = fInternalEnergyBoundary1 + ((fTimeStep*...
                    (pi*(mHydrDiam(1)/2)^2))/fVolumeBoundary1)*(0-mGodunovFlux(1,3));
                fInternalEnergyBoundary2New = fInternalEnergyBoundary2 + ((fTimeStep*...
                    (pi*(mHydrDiam(iNumberOfProcs)/2)^2))/fVolumeBoundary2)*(mGodunovFlux(this.inCells*iNumberOfPipes+1,3)-0);

                %from the internal energy values of the boundary phases the
                %temperature can be calculated
                fTemperatureBoundary1New = (fInternalEnergyBoundary1New/(fHeatCapacity*fDensityBoundary1New))+fTempRef;
                fTemperatureBoundary2New = (fInternalEnergyBoundary2New/(fHeatCapacity*fDensityBoundary2New))+fTempRef;
                
                %%
                %calculation of the new boundary values for temperature
                %with the influence of the flow procs (temperature value in
                %the pipes as well as delta temperature values for the
                %pipes are only auxilliary values for this)
                
                %Temperature in the pipes without the influence of flow
                %procs
                mTemperaturePipe = zeros(iNumberOfPipes,1);
                mTemperaturePipeWithProcs = zeros(iNumberOfPipes,1);
                mTemperaturePipeNew = zeros(iNumberOfPipes,1);
                mMassPipe = zeros(iNumberOfPipes,1);
                mDeltaTemperaturePipeNew = zeros(iNumberOfPipes,1);
                if strcmp(this.mDeltaTemperaturePipe, 'empty')
                    this.mDeltaTemperaturePipe = zeros(iNumberOfPipes,1);
                end
                n = 1;
                k = this.inCells;
                while n <= iNumberOfPipes
                    
                    mTemperaturePipe(n) = (sum(mTemperatureNew(k-(this.inCells-1):k))/this.inCells)+this.mDeltaTemperaturePipe(n); 
                    
                    mMassPipe(n) = (sum(mDensityNew(k-(this.inCells-1):k))/this.inCells)*(pi*(((mHydrDiam(iNotZeroHydrLength(n))/2)^2)/2)^2)*mCellLength(n);
                        
                    if mHydrLength(n) == 0 
                        k = k+0;
                    else 
                        k = k+this.inCells;
                    end
                    n = n+1;
                end
                n = 1;
                m = 1;
                k = this.inCells;
                while n <= iNumberOfPipes
                    %TO DO: Add correct temperature calculation the one
                    %from before was simply wrong.
                    
                    mTemperaturePipeWithProcs(n) = mTemperaturePipe(n)+mDeltaTempComp(m);
                    
                    if mHydrLength(m) ~= 0
                        n = n+1;
                        k = k+this.inCells;
                    else
                        n = n+0;
                        k = k+0;
                    end
                    m = m+1;
                end
      
                if fMassFlow >= 0
                    fTemperatureBoundary2NewWithProcs = fTemperatureBoundary2New;
                    fTemperatureBoundary1NewWithProcs = fTemperatureBoundary1New;
                    %fTemperatureBoundary1NewWithProcs = fTemperatureBoundary1 + (fTimeStep*fMassFlow*fHeatCapacity)/(fMassBoundary2New*fHeatCapacity)*mTemperaturePipeNew(end);
                else
                    %fTemperatureBoundary2NewWithProcs = fTemperatureBoundary2 + (fTimeStep*fMassFlow*fHeatCapacity)/(fMassBoundary2New*fHeatCapacity)*mTemperaturePipeNew(1);
                    fTemperatureBoundary2NewWithProcs = fTemperatureBoundary2New;
                    fTemperatureBoundary1NewWithProcs = fTemperatureBoundary1New;
                end
                
                %%
                %calculation of the boundary flow speed with friction
                %influence
                
             	%for the next time step it is necessary to save the flow 
                %speed of the fluid at the two exmes    
                fFlowSpeedBoundary1New = mGodunovFlux(1,1)/fDensityBoundary1New;
                fFlowSpeedBoundary2New = mGodunovFlux(this.inCells*iNumberOfPipes+1,1)/fDensityBoundary2New;

              	fReBoundary1New = (fFlowSpeedBoundary1New * mHydrDiam(1))/(fDynamicViscosity/fDensityBoundary1);
                fReBoundary2New = (fFlowSpeedBoundary2New * mHydrDiam(iNotZeroHydrDiam(end)))/(fDynamicViscosity/fDensityBoundary2);
                
                if fReBoundary1New <= 2320
                    fFlowSpeedBoundary1New = 0.5*fFlowSpeedBoundary1New;
                else
                    fFlowSpeedBoundary1New = 0.84*fFlowSpeedBoundary1New;
                end
                if fReBoundary2New <= 2320
                    fFlowSpeedBoundary2New = 0.5*fFlowSpeedBoundary2New;
                else
                    fFlowSpeedBoundary2New = 0.84*fFlowSpeedBoundary2New;
                end
                
                %%
                %intermediate boundary values for pressure and volume
                %assuming ideal conditions. For pressure it is assumed that
                %the liquid does not change its volume. For volume it is
                %assumed that the pressure is constant. These values are 
                %used as starting estimates in the cases where the
                %conditions do not apply
                
                %using the values for density and temperature of the
                %boundary phases definded above it is possible to calculate
                %the pressure assuming no volume change in the liquid phase
                %using the liquid pressure function
                fPressureBoundary1New = solver.matter.fdm_liquid.functions.LiquidPressure(fTemperatureBoundary1New,...
                       fDensityBoundary1New, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                       fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                fPressureBoundary2New = solver.matter.fdm_liquid.functions.LiquidPressure(fTemperatureBoundary2New,...
                       fDensityBoundary2New, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                       fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                   
                %the new volumes in the phases at each boundary assuming
                %the liquid phase is incompressible compared to gas phases
                if fMassFlow >= 0
                    mVolumeBoundaryNew(1) = fVolumeBoundary1 - fTimeStep*(fMassFlow/fDensityBoundary1);
                    mVolumeBoundaryNew(2) = fVolumeBoundary2 + fTimeStep*(fMassFlow/mDensity(end));
                else
                    mVolumeBoundaryNew(1) = fVolumeBoundary1 - fTimeStep*(fMassFlow/mDensity(1));
                    mVolumeBoundaryNew(2) = fVolumeBoundary2 + fTimeStep*(fMassFlow/fDensityBoundary2);
                end
                
                %%
                %getting the values for additional gas phases in the tanks
                
                mVolumeTank = zeros(length(this.oBranch.coExmes),1);
                mVolumeLiquid = zeros(length(this.oBranch.coExmes),1);
                mVolumeGasNew = zeros(length(this.oBranch.coExmes),1);
                iNumberOfPhases = zeros(length(this.oBranch.coExmes),1);

                for k = 1:length(this.oBranch.coExmes)
                    iNumberOfPhases(k) = length(this.oBranch.coExmes{k}.oPhase.oStore.aoPhases);
                end
                
                for k = 1:length(this.oBranch.coExmes)
                    mVolumeTank(k) = this.oBranch.coExmes{k}.oPhase.oStore.fVolume;
                    mVolumeLiquid(k) = this.oBranch.coExmes{k}.oPhase.fVolume;
                    mVolumeGasNew(k) = mVolumeTank(k)-mVolumeBoundaryNew(k);
                    if mVolumeGasNew(k) < 0
                        mVolumeGasNew(k) = 0;
                    end
                end
                
                mPressureGas = zeros(length(this.oBranch.coExmes),1);
                mMolMassGas = zeros(length(this.oBranch.coExmes),1);
                mMassGas = zeros(length(this.oBranch.coExmes),1);
                mTempGas = zeros(length(this.oBranch.coExmes),1);
                
                %gets the values for the gas phases in the stores
                for k = 1:length(this.oBranch.coExmes)
                   if mVolumeTank(k)-mVolumeLiquid(k) ~= 0
                       for m = 1:iNumberOfPhases(k)
                           if strcmp(this.oBranch.coExmes{k}.oPhase.oStore.aoPhases(m).sType, 'gas')
                               %mPressureGas(k) = this.oBranch.coExmes{k}.oPhase.oStore.aoPhases(m).fPressure;
                               mMolMassGas(k) = this.oBranch.coExmes{k}.oPhase.oStore.aoPhases(m).fMolMass;
                               mMassGas(k) = this.oBranch.coExmes{k}.oPhase.oStore.aoPhases(m).fMass;
                               mTempGas(k) = this.oBranch.coExmes{k}.oPhase.oStore.aoPhases(m).fTemp;
                           end
                       end
                   end
                end

                %%
                %calculating a pressure for the gas assuming the volume
                %change from the liquid with constant pressure as startin
                %estimate.
                
                %ideal gas constant
                fR = matter.table.C.R_m;
                %calculates the pressure of the gas assuming the liquid as
                %incompressible. This pressure will be used in case that
                %both a gas and a liquid phase are used in a tank because
                %the simplification that the liquid is incompressible
                %compared to the gas phase is justified.
                for k = 1:length(this.oBranch.coExmes)
                    mPressureGas(k) = (mMassGas(k)*fR*mTempGas(k))/(mMolMassGas(k)*10^-3*mVolumeGasNew(k));
                end      

                %%
                %calculation of the correct pressure and volume in the
                %tanks if liquid and gas phases are used with a nested
                %intervall approach

                %Pressure calculation in the case that tank 1 also
                %contains a gas phase using an iterative nested intervall
                %scheme 
                
                %the left and right border for the search intervall are
                %calculated
                fVolumeGas1_X = mVolumeTank(1)-mVolumeLiquid(1);
                fVolumeGas1_Y = mVolumeGasNew(1);
                
                fErrorTank1_X = 1;
                fErrorTank1_Y = 1;
                counter1 = 1;
                %if the two border do not contain the zero point it is 
                %necessary to shift the borders until they contain it
                while sign(fErrorTank1_X) == sign(fErrorTank1_Y) && counter1 <= 200
                    fDensityLiquid1_X = fMassBoundary1New/(mVolumeTank(1)-fVolumeGas1_X);
                    mPressureGas1_X = (mMassGas(1)*fR*mTempGas(1))/(mMolMassGas(1)*10^-3*fVolumeGas1_X);
                    fPressureLiquid1_X = solver.matter.fdm_liquid.functions.LiquidPressure(fTemperatureBoundary1New,...
                                fDensityLiquid1_X, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                                fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                    fErrorTank1_X = mPressureGas1_X-fPressureLiquid1_X;      

                    fDensityLiquid1_Y = fMassBoundary1New/(mVolumeTank(1)-fVolumeGas1_Y);
                    mPressureGas1_Y = (mMassGas(1)*fR*mTempGas(1))/(mMolMassGas(1)*10^-3*fVolumeGas1_Y);
                    fPressureLiquid1_Y = solver.matter.fdm_liquid.functions.LiquidPressure(fTemperatureBoundary1New,...
                                fDensityLiquid1_Y, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                                fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                    fErrorTank1_Y = mPressureGas1_Y-fPressureLiquid1_Y;  
                    
                    %if the signs are identical the search intervall is
                    %increased. Depending on wether the sign is positive or
                    %negative the left or right border for the search
                    %intervall is moved
                    if fMassFlow >= 0
                        if sign(fErrorTank1_X) == sign(fErrorTank1_Y) && sign(fErrorTank1_Y) == 1
                            fVolumeGas1_Y = fVolumeGas1_Y + (0.0001*fVolumeGas1_Y);
                        elseif sign(fErrorTank1_X) == sign(fErrorTank1_Y) && sign(fErrorTank1_X) == -1
                            fVolumeGas1_X = fVolumeGas1_X - (0.0001*fVolumeGas1_X);
                        end
                    elseif fMassFlow < 0
                        if sign(fErrorTank1_X) == sign(fErrorTank1_Y) && sign(fErrorTank1_Y) == -1
                            fVolumeGas1_Y = fVolumeGas1_Y - (0.0001*fVolumeGas1_Y);
                        elseif sign(fErrorTank1_X) == sign(fErrorTank1_Y) && sign(fErrorTank1_X) == 1
                            fVolumeGas1_X = fVolumeGas1_X + (0.0001*fVolumeGas1_X);
                        end
                    end
                    counter1 = counter1 + 1;
                end
       
                fErrorTank1 = fErrorTank1_Y;
   
                counter1 = 1;
                
                if mMolMassGas(1) ~= 0
                    while abs(fErrorTank1) > 10^-5 && counter1 <= 500
                        
                        fVolumeGas1_Z = fVolumeGas1_X+((fVolumeGas1_Y-fVolumeGas1_X)/2);
                        
                        if (fVolumeGas1_Z - fVolumeGas1_X) == 0
                            %in this case the numerical accuracy is reached
                            %and a more accurate result is not possible.
                            counter1 = 600;
                        end

                        fDensityLiquid1_X = fMassBoundary1New/(mVolumeTank(1)-fVolumeGas1_X);
                        fDensityLiquid1_Z = fMassBoundary1New/(mVolumeTank(1)-fVolumeGas1_Z);
                        
                        mPressureGas1_X = (mMassGas(1)*fR*mTempGas(1))/(mMolMassGas(1)*10^-3*fVolumeGas1_X);
                        mPressureGas1_Z = (mMassGas(1)*fR*mTempGas(1))/(mMolMassGas(1)*10^-3*fVolumeGas1_Z);
                        
                        fPressureLiquid1_X = solver.matter.fdm_liquid.functions.LiquidPressure(fTemperatureBoundary1New,...
                            fDensityLiquid1_X, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                            fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                        fPressureLiquid1_Z = solver.matter.fdm_liquid.functions.LiquidPressure(fTemperatureBoundary1New,...
                            fDensityLiquid1_Z, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                            fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                        
                        fErrorTank1_X = mPressureGas1_X-fPressureLiquid1_X;
                        fErrorTank1_Z = mPressureGas1_Z-fPressureLiquid1_Z;
                        fErrorTank1 = fErrorTank1_Z;
                        
                        if fErrorTank1_Z == 0
                            counter1 = inf;
                        elseif sign(fErrorTank1_Z) == sign(fErrorTank1_X)
                            fVolumeGas1_X = fVolumeGas1_Z;
                        else
                            fVolumeGas1_Y = fVolumeGas1_Z;
                        end
                 
                        counter1 = counter1+1;
                        
                    end
                    mVolumeGasNew(1) = fVolumeGas1_Z;
                    fDensityBoundary1New = fDensityLiquid1_Z;
                    mPressureGas(1) = mPressureGas1_Z;
                end

                %Pressure calculation in the case that tank 2 also
                %contains a gas phase using an iterative nested intervall 
                %scheme 
                
                %the left and right border for the search intervall are
                %calculated
                fVolumeGas2_X = mVolumeTank(2)-mVolumeLiquid(2);
                fVolumeGas2_Y = mVolumeGasNew(2);
                
                fErrorTank2_X = 1;
                fErrorTank2_Y = 1;
                counter2 = 1;
                %if the two border do not contain the zero point it is 
                %necessary to shift the borders until they contain it
                while sign(fErrorTank2_X) == sign(fErrorTank2_Y) && counter2 <= 200
                    fDensityLiquid2_X = fMassBoundary2New/(mVolumeTank(2)-fVolumeGas2_X);
                    mPressureGas2_X = (mMassGas(2)*fR*mTempGas(2))/(mMolMassGas(2)*10^-3*fVolumeGas2_X);
                    fPressureLiquid2_X = solver.matter.fdm_liquid.functions.LiquidPressure(fTemperatureBoundary2New,...
                                fDensityLiquid2_X, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                                fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                    fErrorTank2_X = mPressureGas2_X-fPressureLiquid2_X;      

                    fDensityLiquid2_Y = fMassBoundary2New/(mVolumeTank(2)-fVolumeGas2_Y);
                    mPressureGas2_Y = (mMassGas(2)*fR*mTempGas(2))/(mMolMassGas(2)*10^-3*fVolumeGas2_Y);
                    fPressureLiquid2_Y = solver.matter.fdm_liquid.functions.LiquidPressure(fTemperatureBoundary2New,...
                                fDensityLiquid2_Y, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                                fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                    fErrorTank2_Y = mPressureGas2_Y-fPressureLiquid2_Y;  
                    
                    %if the signs are identical the search intervall is
                    %increased. Depending on wether the sign is positive or
                    %negative the left or right border for the search
                    %intervall is moved
                    if fMassFlow >= 0
                        if sign(fErrorTank2_X) == sign(fErrorTank2_Y) && sign(fErrorTank2_Y) == -1
                            fVolumeGas2_Y = fVolumeGas2_Y - (0.0001*fVolumeGas2_Y);
                        elseif sign(fErrorTank2_X) == sign(fErrorTank2_Y) && sign(fErrorTank2_X) == 1
                            fVolumeGas2_X = fVolumeGas2_X + (0.0001*fVolumeGas2_X);
                        end
                    elseif fMassFlow < 0
                        if sign(fErrorTank2_X) == sign(fErrorTank2_Y) && sign(fErrorTank2_Y) == -1
                            fVolumeGas2_Y = fVolumeGas2_Y + (0.0001*fVolumeGas2_Y);
                        elseif sign(fErrorTank2_X) == sign(fErrorTank2_Y) && sign(fErrorTank2_X) == 1
                            fVolumeGas2_X = fVolumeGas2_X - (0.0001*fVolumeGas2_X);
                        end
                    end
                    
                    counter2 = counter2 + 1;
                end
       
                fErrorTank2 = fErrorTank2_Y;
   
                counter2 = 1;
                
                if mMolMassGas(2) ~= 0
                    while abs(fErrorTank2) > 10^-5 && counter2 <= 500
                        
                        fVolumeGas2_Z = fVolumeGas2_X+((fVolumeGas2_Y-fVolumeGas2_X)/2);
                        
                        if (fVolumeGas2_Z - fVolumeGas2_X) == 0
                            %in this case the numerical accuracy is reached
                            %and a more accurate result is not possible.
                            counter2 = 600;
                        end

                        fDensityLiquid2_X = fMassBoundary2New/(mVolumeTank(2)-fVolumeGas2_X);
                        fDensityLiquid2_Z = fMassBoundary2New/(mVolumeTank(2)-fVolumeGas2_Z);
                        
                        mPressureGas2_X = (mMassGas(2)*fR*mTempGas(2))/(mMolMassGas(2)*10^-3*fVolumeGas2_X);
                        mPressureGas2_Z = (mMassGas(2)*fR*mTempGas(2))/(mMolMassGas(2)*10^-3*fVolumeGas2_Z);
                        
                        fPressureLiquid2_X = solver.matter.fdm_liquid.functions.LiquidPressure(fTemperatureBoundary2New,...
                            fDensityLiquid2_X, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                            fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                        fPressureLiquid2_Z = solver.matter.fdm_liquid.functions.LiquidPressure(fTemperatureBoundary2New,...
                            fDensityLiquid2_Z, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                            fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                        
                        fErrorTank2_X = mPressureGas2_X-fPressureLiquid2_X;
                        fErrorTank2_Z = mPressureGas2_Z-fPressureLiquid2_Z;
                        fErrorTank2 = fErrorTank2_Z;
                        
                        if fErrorTank2_Z == 0
                            counter2 = inf;
                        elseif sign(fErrorTank2_Z) == sign(fErrorTank2_X)
                            fVolumeGas2_X = fVolumeGas2_Z;
                        else
                            fVolumeGas2_Y = fVolumeGas2_Z;
                        end
                 
                        counter2 = counter2+1;
                        
                    end
                    mVolumeGasNew(2) = fVolumeGas2_Z;
                    fDensityBoundary2New = fDensityLiquid2_Z;
                    mPressureGas(2) = mPressureGas2_Z;
                end
                
                

                %% 
                %decision which values for pressure and volume in which
                %tank should be used
                
                %sets the new volumes for the liquid phase in the case that
                %a gas phase is also present in the tank
                if mMolMassGas(1) ~= 0
                    mVolumeBoundaryNew(1) = (mVolumeTank(1)-mVolumeGasNew(1));
                else
                    mVolumeBoundaryNew(1) = mVolumeLiquid(1);
                end
                if mMolMassGas(2) ~= 0
                    mVolumeBoundaryNew(2) = (mVolumeTank(2)-mVolumeGasNew(2));
                else
                    mVolumeBoundaryNew(2) = mVolumeLiquid(2);
                end

                %Both tanks contain a liquid+gas phase
                if mMolMassGas(1) ~= 0 && mMolMassGas(2) ~= 0
                    fPressureTank1 = mPressureGas(1);
                    fPressureTank2 = mPressureGas(2);
                %only tank 1 contains a liquid+gas phase and the other tank
                %is completly filled with liquid
                elseif mMolMassGas(1) ~= 0 && mMolMassGas(2) == 0
                    fPressureTank1 = mPressureGas(1);
                    fPressureTank2 = fPressureBoundary2New;
                %only tank 2 contains a liquid+gas phase and the other tank
                %is completly filled with liquid
              	elseif mMolMassGas(1) == 0 && mMolMassGas(2) ~= 0
                    fPressureTank2 = mPressureGas(2);
                    fPressureTank1 = fPressureBoundary1New;
                else
                    fPressureTank1 = fPressureBoundary1New;
                    fPressureTank2 = fPressureBoundary2New;
                end

                %% 
                %calculates the gravity influence on the boundary pressures
                %and writes new values into the exmes and phases where
                %necessary
                
                %LiquidLevel in the Stores
                %TO DO: This is a simple workaround till more specific
                %geometric features are added to stores.
                fLiquidLevel1New = mVolumeBoundaryNew(1)*(fLiquidLevel1Old/mVolumeLiquid(1));
                fLiquidLevel2New = mVolumeBoundaryNew(2)*(fLiquidLevel2Old/mVolumeLiquid(2));
                
                %sets the new volumes for the liquid phases in case that a
                %gas phase is also present in the tank
                if mMolMassGas(1) ~= 0
                    this.oBranch.coExmes{1}.oPhase.setVolume(mVolumeBoundaryNew(1));
                end
                if mMolMassGas(2) ~= 0
                    this.oBranch.coExmes{2}.oPhase.setVolume(mVolumeBoundaryNew(2));  
                end
                
                %pressure on the exmes with regard to the liquid level and
                %acceleration
                fPressureExme1 = fPressureTank1+(fLiquidLevel1New*fAcceleration1*fDensityBoundary1New);
                fPressureExme2 = fPressureTank2+(fLiquidLevel2New*fAcceleration2*fDensityBoundary2New);       

                %sets the new values for pressure, temperature and flow
                %speed at the exmes
                %setPortProperties(this, fPortPressure, fPortTemperature, fFlowSpeed, fLiquidLevel, fAcceleration, fDensity)
                this.oBranch.coExmes{1}.setPortProperties(fPressureExme1, fTemperatureBoundary1NewWithProcs, fFlowSpeedBoundary1New, fLiquidLevel1New, fAcceleration1, fDensityBoundary1New);
                this.oBranch.coExmes{2}.setPortProperties(fPressureExme2, fTemperatureBoundary2NewWithProcs, fFlowSpeedBoundary2New, fLiquidLevel2New, fAcceleration2, fDensityBoundary2New);
                
                
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
                
                if strcmp(this.fInitialPressureDifference, 'empty')
                    this.fInitialPressureDifference = abs(fPressureBoundary1-fPressureBoundary2);
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
                
                if this.fPressureResidual ~= 0 && ~strcmp(this.fInitialPressureDifference, 'empty') && (abs(fPressureBoundary1-fPressureBoundary2) < this.fInitialPressureDifference*this.fPressureResidual)
                    this.iPressureResidualCounter = this.iPressureResidualCounter+1;
                elseif this.iPressureResidualCounter ~= 0 && (abs(fPressureBoundary1-fPressureBoundary2) > this.fInitialPressureDifference*this.fPressureResidual)
                    %resets the counter to 0 if the target is no longer
                    %reached
                    this.iPressureResidualCounter = 0;
                end
                
                %%
                %writes the newly calculated values into the object
                %parameters of this branch in order to use them in the next
                %tick
                
                this.mPressureOld = mPressureNew;
                this.mInternalEnergyOld = mInternalEnergyNew;
                this.mDensityOld = mDensityNew;
                this.mFlowSpeedOld = mFlowSpeedNew;
                
                %%
                %finnaly sets the time step for the branch as well as the
                %mass flow rate
                
                %sets the timestep from this branch for the base branch
                this.setTimeStep(fTimeStep);
                
                %calls the update for the base branch using the newly
                %calculated mass flow
                %branch(this, fFlowRate, afPressures, afTemps)
                update@solver.matter.base.branch(this, fMassFlow);
                
            end

            
        end
    end
 
end