classdef branch_liquid < solver.matter.base.branch
%%Godunov Solver branch for compressible liquids
%
%this is a solver for flows in a branch containing liquids it can be
%called using 
%
%WARNING: Currently fix matter values for water are set in the solver. If a
%         calcuation with a different should be made these values have to
%         be changed manually. Simply search this file for TO DO and all
%         sections where this is the case can be found easily.
%
%solver.matter.fdm_liquid.branch_liquid(oBranch, iCells,...
%               fPressureResidual, fMassFlowResidual, fCourantNumber,...
%               sCourantAdaption)
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
%fPressureResidualFactor: sets the residual target factor for the pressure
%                   difference depending on the initial pressure. 
%                   Meaning the PressureResidualFactor is multiplied with
%                   the initial pressure difference to get a target
%                   pressure difference after which the calculation is
%                   assumed as finished. Disabled if nothing is specified
%
%fMassFlowResidualFactor: sets the residual target for the massflow
%                   depending on the maximum massflow during the 
%                   simulation. Meaning the MassFlowResidualFactor is 
%                   multiplied with the maximum massflow that occured so
%                   far in the simulation to get a target
%                   massflow difference after which the calculation is
%                   assumed to have reached a time independend stead 
%                   state. Disabled if nothing is specified
%
%fCourantNumber: is used to set the initial, or if adaption is disabled the
%                overall courant number. The courant number is a factor
%                that directily influences the time step with values
%                between ]0,1]. For a courant number of 0.5 the time step
%                is only half of its value and for 0.1 its only one tenth
%                etc.
%
%sCourantAdaption: is a struct that allows to set certain values for
%                  the adaption of the courant number that directly
%                  influences the time step. Its fields are:
%                  bAdaption: which is a either true or false and 
%                             decides whether the courant number should 
%                             be increased at all 
%            fIncreaseFactor: is a factor multiplied to the courant 
%                             number of the current step to increase
%                             it. Therefore the factor should be larger
%                             than 1.
%      iTicksBetweenIncrease: Decides how many ticks the solver will
%                             wait between the increases of the courant
%                             number.
%              iInitialTicks: Decides after how many ticks the increase
%                             should start.
%          fMaxCourantNumber: Maximum Courant Number that will be reached.
%
%example struct: sCourantAdaption = struct( 'bAdaption', false,...
%       'fIncreaseFactor', 1.001, 'iTicksBetweenIncrease', 100,...
%       'iInitialTicks', 10000);
%
%if one of the two residual conditions shall not be applied for the
%simulation the residual simply has to be set to 0
%
%Information for the programming of components that work with this solver:
%
%The solver searches each component for the following properties:
%
%   fHydrDiam     :The hydraulic diameter of the component which is used to
%                  calculate the crosssection area of the component. The
%                  smallest hydraulic diameter is set as the overall
%                  diameter for the calculation and therefore used to
%                  calculate massflows etc. If an actual component(like a
%                  pipe or a valve) as a hydraulic diameter of zero the
%                  massflow will also be zero and the solver will not
%                  calculate anything. However if the property is not
%                  defined it will not influence the calculation and the
%                  minimum hydraulic diameter of another component will be
%                  used.
%
%   fHydrLength   :The hydraulic length is used to calculate the overall
%                  length of the branch. The sum over all hydraulic
%                  lengthes of the components will be divided with the
%                  number of cells to get the cell length necessary to
%                  calculate the cell volume and therefore the cell values.
%
%   fDeltaPressure:This property is used to set changes in pressures
%                  created from components. The value should always be
%                  positive the inlfuence of the pressure difference is
%                  discerned by the next property iDir.
%
%   iDir          :This property decides whether the pressure difference is
%                  undirected and therefore a pressure loss that always
%                  acts against the flow or if the pressure difference is
%                  assosciated with a defined direction that can either be
%                  negative or positive. The values should be 0 in case of
%                  undirected and -1 or +1 in case of a directed  pressure
%                  difference
%
%   fDeltaTemp    :This property decides how much the fluid will increase
%                  or decrease its temperature. For a temperature increase
%                  the value should be positive and for a decrease negative
%
%If any of these properties is not defined in the component it will be set
%to zero for the calculation but the solver will not crash. Any properties 
%that use different names will have no influence on the solver.

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
        
        %residual target factor for pressure (see the comment for the input
        %variables at the beginning of this file for further explanation)
        fPressureResidualFactor = 0;
        
        %residual target for mass flow (see the comment for the input
        %variables at the beginning of this file for further explanation)
        fMassFlowResidualFactor = 0;
        
        %the minimum mass flow during the simulation is saved in this variable
        fMassFlowMin = 'empty'; %kg/s
        
        %the mass flow of the previous timestep is saved in this variable
        mMassFlowOld = 'empty'; %kg/s
        
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
        
        iSteadyState = 0;
        
        %values inside the branch cells for the previous time step
        mVirtualPressureOld       = 'empty';
        mVirtualInternalEnergyOld = 'empty';
        mVirtualDensityOld        = 'empty';
        mFlowSpeedOld             = 'empty';
        mVirtualTemperatureOld    = 'empty';
        
        mPressureOld3             = 'empty';
        mPressureOld2             = 'empty';
        mPressureOld1             = 'empty';
        mPressureOld              = 'empty';
        mInternalEnergyOld        = 'empty';
        mDensityOld               = 'empty';
        mTemperatureOld           = 'empty';
        
        fFlowSpeedBoundary1Old    = 0;
        fFlowSpeedBoundary2Old    = 0;
        
        sCourantAdaption = struct( 'bAdaption', false, 'fIncreaseFactor', 1.001, 'iTicksBetweenIncrease', 100, 'iInitialTicks', 10000, 'iTimeStepAdaption', 0, 'fMaxCourantNumber', 1);
        
        mPressureLoss;
        mFlowSpeedLoss;
        
        %Delta temperature in the pipes created from flow procs
        mDeltaTemperaturePipe = 'empty';
        
        %these values are not required for the calculation but can be used
        %to plot the respective values.
        fTimeStepBranch
        
    end

    methods 
        %%
        %definition of the branch and the possible input values.
        %For explanation about the values see initial comment section.
        function this = branch_liquid(oBranch, iCells, fPressureResidualFactor, fMassFlowResidualFactor, fCourantNumber, sCourantAdaption)
            this@solver.matter.base.branch(oBranch);  
            
            if nargin == 2
                this.inCells = iCells;
            elseif nargin == 3
                this.inCells                 = iCells;
                this.fPressureResidualFactor = fPressureResidualFactor;
            elseif nargin == 4
                this.inCells                 = iCells;
                this.fPressureResidualFactor = fPressureResidualFactor;
                this.fMassFlowResidualFactor = fMassFlowResidualFactor;
            elseif nargin == 5
                this.inCells                 = iCells;
                this.fPressureResidualFactor = fPressureResidualFactor;
                this.fMassFlowResidualFactor = fMassFlowResidualFactor;
                this.fCourantNumber          = fCourantNumber;
            elseif nargin == 6    
                this.inCells                 = iCells;
                this.fPressureResidualFactor = fPressureResidualFactor;
                this.fMassFlowResidualFactor = fMassFlowResidualFactor;
                this.fCourantNumber          = fCourantNumber;
                this.sCourantAdaption        = sCourantAdaption;
                this.sCourantAdaption.iTimeStepAdaption = 0;
            end
                        
            %because of the logic of the adaption algorithm the Adaption of
            %the courant number is completly stopped for the value 2.
            if this.sCourantAdaption.bAdaption == 0
                this.sCourantAdaption.bAdaption = 2;
            end
            
            %checks the range of the courant number. For 0 or smaller the
            %calculation will no longer work while numbers larger than 1
            %are considered instable but if the user defines them they can
            %be used (with crashes in the solver most probable)
            if this.fCourantNumber <= 0
               error('courant number of 0 or lower is not allowed')
            elseif this.fCourantNumber > 1
                string=('normally allowed range for courant number is ]0,1] and the current definition of a number larger than one will most likely lead to stability problems');
                disp(string);
            end
            
            %with this the branch is considered not updated after its
            %initilaization
            oBranch.setOutdated();
            
        end
    end
    
    methods (Access = protected)
        
        function update(this)
            
            %% 
            %get all neccessary variables from the boundaries, procs etc
            
            %a Temperature Reference has to be defined in order to
            %calculate the internal Energy
            fTempRef = 293;

            %TO DO:Make heat capacity Calculations temperature and pressure
            %dependant
            if this.oBranch.fFlowRate >= 0
                fHeatCapacity = this.oBranch.oContainer.oData.oMT.calculateHeatCapacity(this.oBranch.aoFlows(1,1));
            else
                fHeatCapacity = this.oBranch.oContainer.oData.oMT.calculateHeatCapacity(this.oBranch.aoFlows(1,end));
            end
            
            %gets the total number of processors used in the branch
            iNumberOfProcs = length(this.oBranch.aoFlowProcs);
            
            %the meta values are used to decide whether a component even
            %has the respective attribute because not necessarily all
            %components have alle the attributes
            mHydrDiam                   = zeros(iNumberOfProcs,1);
            mHydrDiamValve              = zeros(iNumberOfProcs,1);
            mHydrLength                 = zeros(iNumberOfProcs,1);
            mDeltaPressureComp          = zeros(iNumberOfProcs,1);
            mDirectionDeltaPressureComp = zeros(iNumberOfProcs,1); 
            mDeltaTempComp              = zeros(iNumberOfProcs,1);
            
            for k = 1:iNumberOfProcs
                %checks wether the flow procs contain the properties of
                %hydraulic diameter, length or delta pressure
                metaHydrDiam               = findprop(this.oBranch.aoFlowProcs(1,k), 'fDiameter');
                metaHydrLength             = findprop(this.oBranch.aoFlowProcs(1,k), 'fLength');
                metaDeltaPressure          = findprop(this.oBranch.aoFlowProcs(1,k), 'fDeltaPressure');
                metaDirectionDeltaPressure = findprop(this.oBranch.aoFlowProcs(1,k), 'iDir');
                metaDeltaTempComp          = findprop(this.oBranch.aoFlowProcs(1,k), 'fDeltaTemp');
                
                %if the processor with index k has the respective property
                %its value is written into the respective vector. If not
                %the vector entry remains zero or for the diameter -1.
                if ~isempty(metaHydrDiam)
                    mHydrDiam(k) = [ this.oBranch.aoFlowProcs(1,k).fDiameter ];
                end
                if ~isempty(metaHydrLength)
                    mHydrLength(k) = [ this.oBranch.aoFlowProcs(1,k).fLength ];
                end
                if ~isempty(metaHydrDiam) && mHydrLength(k) == 0
                    mHydrDiamValve(k) = [ this.oBranch.aoFlowProcs(1,k).fDiameter ];
                else
                    %this is necessary in order to discern between procs
                    %that simply dont have a diameter definition and one
                    %that actually have a diameter of 0 like closed valves.
                    mHydrDiamValve(k) = -1;
                end
                if ~isempty(metaDeltaPressure)
                    mDeltaPressureComp(k) = [ this.oBranch.aoFlowProcs(1,k).fDeltaPressure ];
                end
                if ~isempty(metaDirectionDeltaPressure)
                    mDirectionDeltaPressureComp(k) = [ this.oBranch.aoFlowProcs(1,k).iDir ];
                end
                if ~isempty(metaDeltaTempComp)
                    mDeltaTempComp(k) = [ this.oBranch.aoFlowProcs(1,k).fDeltaTemp ];
                end
            end
            
            %get the properties at the left and right side of the branch.
            %It is important to get the pressure from the exme and not the 
            %store since the liquid exme also tales gravity effects into 
            %account.
            [fPressureBoundary1, fTemperatureBoundary1]  = this.oBranch.coExmes{1}.getPortProperties();
            [fPressureBoundary2, fTemperatureBoundary2]  = this.oBranch.coExmes{2}.getPortProperties();
            
            %volume and mass are then taken fromt he respective phase
            
            fVolumeBoundary1 = this.oBranch.coExmes{1}.oPhase.fVolume;  
            fVolumeBoundary2 = this.oBranch.coExmes{2}.oPhase.fVolume; 
            fMassBoundary1   = this.oBranch.coExmes{1}.oPhase.fMass; 
            fMassBoundary2   = this.oBranch.coExmes{2}.oPhase.fMass;
            
            %either takes the values from the previous time step for the
            %boundary flow speeds between the first/last cell and the
            %stores or uses the initialization of 0 for the first time step.
            fFlowSpeedBoundary1 = this.fFlowSpeedBoundary1Old;
            fFlowSpeedBoundary2 = this.fFlowSpeedBoundary2Old;
            
            %density in the phases at each side of the store are
            %mass/volume
            fDensityBoundary1 = fMassBoundary1/fVolumeBoundary1;
            fDensityBoundary2 = fMassBoundary2/fVolumeBoundary2;
            
            %if the pressure difference between the two boundaries of the
            %branch is lower than a certain threshhold the system is 
            %assumed to have reached a balanced state, averaging the 
            %remaining pressure difference and allowing infinite time
            %steps.
            if this.iPressureResidualCounter == 1000 && this.oBranch.oContainer.oTimer.iTick > 1000
                
                fMassFlow = 0;
                update@solver.matter.base.branch(this, fMassFlow);
                
                for k = 1: length(this.oBranch.aoFlowProcs)
                    this.oBranch.aoFlowProcs(1,k).update();
                end
                
                this.setTimeStep(2);
                
                update@solver.matter.base.branch(this, 0);
            %%    
            %if the counter for how often the residual target for the mass
            %flow has been undercut reaches a certain value the steady time
            %independent state is reached and the massflow
            %value from the previous timestep can be used again.
            elseif  (this.iMassFlowResidualCounter == 2 && this.oBranch.oContainer.oTimer.iTick > 1000 && this.iSteadyState < 100) || (this.iSteadyState < 100 && this.iSteadyState ~= 0)
                
                if this.iSteadyState == 0
                    this.iSteadyState = 1;
                else
                    this.iSteadyState = this.iSteadyState+1;
                end
                
                fTimeStep = 0.0001;
                
                this.setTimeStep(fTimeStep);
            
                fMassFlow = sum(this.mMassFlowOld)/length(this.mMassFlowOld);
                update@solver.matter.base.branch(this, fMassFlow);
                
                %tells the stores when to update
                this.oBranch.coExmes{1, 1}.oPhase.oStore.setNextExec(this.oBranch.oContainer.oTimer.fTime+fTimeStep);
                this.oBranch.coExmes{2, 1}.oPhase.oStore.setNextExec(this.oBranch.oContainer.oTimer.fTime+fTimeStep);
                
                for k = 1: length(this.oBranch.aoFlowProcs)
                    this.oBranch.aoFlowProcs(1,k).update();
                end
                
                %TO DO: Temperature Calculation in this case?
                
            %%    
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
                
                %checks if either the a pipe had diameter 0 or if a valve
                %has diameter zero
                if bAbort || length(find(mHydrDiamValve)) ~= length(mHydrDiamValve)
                    this.mMassFlowOld(1) = 0;
                    %sets the timestep from this branch for the base branch
                    this.setTimeStep(inf);

                    %calls the update for the base branch using the newly
                    %calculated mass flow
                    %branch(this, fFlowRate, afPressures, afTemperatures)
                    update@solver.matter.base.branch(this, 0);
                    return
                end
                
                %minimal diameters in the system without zero elements
                %because if a relevant element has the entry zero the
                %calculation is aborted by the above conditions.
                fMinHydrDiam = min(mHydrDiam(mHydrDiam > 0));
                
                %if the solver has already reached steady state the courant
                %number for the occasional recalculation is set to 1
                if this.iSteadyState > 0
                    this.fCourantNumber = 1;
                end
                
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
                        if ~strcmp(this.mMassFlowOld(1), 'empty') && this.mMassFlowOld(1) > 0
                            fPressureBoundary1WithProcs = fPressureBoundary1WithProcs - mDeltaPressureComp(k);
                        elseif ~strcmp(this.mMassFlowOld(1), 'empty') && this.mMassFlowOld(1) < 0
                            fPressureBoundary2WithProcs = fPressureBoundary2WithProcs - mDeltaPressureComp(k);
                        end
                    end
                end
                
                %gets the boundary densities
                fDensityBoundary1 = this.oBranch.coExmes{1,1}.oPhase.fDensity;
                
             	fDensityBoundary2 = this.oBranch.coExmes{2,1}.oPhase.fDensity;
                
                %%
                %sets the initial values for pressure, density, internal 
                %energy, temperature and flow speed in the cells either 
                %using the minimal boundary values or the values from the 
                %previous time step
                
                %in the first step where no values inside the cells exist
                %the cells are initialzied on the minimum temperature
                %boundary values because an increase in temperature is more
                %stable than a decrease
                
                %note the difference between the virtual pressure and the
                %later defined pressure is that in the virtual pressure
                %variable for each no influence from procs in the cell
                %itself is applied
                if strcmp(this.mVirtualPressureOld,'empty')
                    
                    mVirtualInternalEnergy = zeros(this.inCells, 1);
                    mVirtualDensity = zeros(this.inCells, 1);
                    mFlowSpeed = zeros(this.inCells, 1);
                    mVirtualTemperature = zeros((this.inCells), 1);
                    mVirtualPressure = zeros((this.inCells), 1);
                    
                    for k = 1:1:(this.inCells)
                        if fTemperatureBoundary1 < fTemperatureBoundary2
                            mVirtualPressure(k,1)       = fPressureBoundary1;
                            mVirtualInternalEnergy(k,1) = fInternalEnergyBoundary1;
                            mVirtualDensity(k,1)        = fDensityBoundary1;
                            mVirtualTemperature(k,1)    = fTemperatureBoundary1;
                        elseif (fTemperatureBoundary1 == fTemperatureBoundary2) &&(fPressureBoundary1WithProcs <= fPressureBoundary2WithProcs)
                            mVirtualPressure(k,1)       = fPressureBoundary1;
                            mVirtualInternalEnergy(k,1) = fInternalEnergyBoundary1;
                            mVirtualDensity(k,1)        = fDensityBoundary1;
                            mVirtualTemperature(k,1)    = fTemperatureBoundary1;
                        else
                            mVirtualPressure(k,1)       = fPressureBoundary2;
                            mVirtualInternalEnergy(k,1) = fInternalEnergyBoundary2;
                            mVirtualDensity(k,1)        = fDensityBoundary2;
                            mVirtualTemperature(k,1)    = fTemperatureBoundary2;
                        end
                    end
                else
                    %variables from the flow processors (these are vectors
                    %containing the values for each cell)
                    mVirtualPressure       = this.mVirtualPressureOld; %[kg/(m*s^2)]
                    mVirtualInternalEnergy = this.mVirtualInternalEnergyOld; %internal energy [J]       
                    mVirtualDensity        = this.mVirtualDensityOld; %density [kg/m³]
                    mFlowSpeed             = this.mFlowSpeedOld;  %velocity [m/s]
                    mVirtualTemperature    = this.mVirtualTemperatureOld; %temperature [K]
                end
                

                %%                
                %defines the cell length by dividing the whole length of the
                %branch with the number of vells
                fCellLength = sum(mHydrLength)/this.inCells;

                %%
                %since not every component is discretized on its own it is
                %necessary to discern in which cell which component ends.
                %For a pipe having a length of 0.3m with a cell length
                %of 0.16 m the entry of mCompCellPosition would be 2
                mCompCellPosition = zeros(this.inCells, 1);
                
                if (~strcmp(this.mMassFlowOld(1), 'empty') && this.mMassFlowOld(1) >= 0) || (fPressureBoundary1WithProcs >= fPressureBoundary2WithProcs)
                    for k = 1:length(mHydrLength)
                        mCompCellPosition(k)=ceil(sum(mHydrLength(1:k))/fCellLength);
                        if (mod(sum(mHydrLength(1:k)),fCellLength) == 0) && (mCompCellPosition(k) ~= this.inCells)
                            mCompCellPosition(k) = mCompCellPosition(k)+1;
                        end
                    end
                %the definition for the end position changes if the flow
                %direction changes since the previous inlet of the
                %component is now its outlet
                else
                    mCompCellPosition(1) = 1;
                    for k = 2:length(mHydrLength)
                        mCompCellPosition(k)=ceil(sum(mHydrLength(1:(k-1)))/fCellLength);
                    end
                end
                
                %mPressure contains the actual cell values including the
                %proc pressure
                mPressureWithoutLoss   = mVirtualPressure;
                mPressure              = mVirtualPressure;
                mTemperature           = mVirtualTemperature;
                mInternalEnergy        = mVirtualInternalEnergy;
                mDensity               = mVirtualDensity;
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
                   	%the actual temperatue is calculated from the sum of the
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
                        %afMass cannot change within a branch so using the
                        %first flow for all is sufficient
                        mDensity(k) = this.oBranch.oContainer.oData.oMT.calculateDensity('liquid', this.oBranch.aoFlows(1,1).arPartialMass, mTemperature(k), mPressure(k));
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
%can change during the calculation but the numbering of the fluxes and
%cells remains the same regardless of the flow case.
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
                
                %This calculation is only correct directly for the first
                %Godunov Flux component. For the second component some
                %changes have to be made at the position of pressure
                %influencing procs but in all other cases the here
                %calculated fluxes are used.
                %Note that for this calculation pressure loss in the cells
                %is neglected. This is the case because the pressure loss
                %is modelled as a reduction in flow speed at the end of the
                %step calculation. This proved to be a lot more stable
                %since modelling the pressure directly here resulted in
                %sometimes having the loss pull the fluid faster through
                %the pipes etc.
                
                if mCompCellPosition(1) == 1 &&  sum(mDeltaPressureComp(mCompCellPosition == 1).*mDirectionDeltaPressureComp(mCompCellPosition == 1)) < 0 
                    [mGodunovFlux(1,:), mMaxWaveSpeed(1,1), mPressureStar(1,1)] = solver.matter.fdm_liquid.functions.HLLC(this, fPressureBoundary1, fDensityBoundary1, fFlowSpeedBoundary1, fInternalEnergyBoundary1,...
                        mPressureWithoutLoss(1), mDensity(1), mFlowSpeed(1), mInternalEnergy(1), fTemperatureBoundary1, mTemperature(1));

                else
                    [mGodunovFlux(1,:), mMaxWaveSpeed(1,1), mPressureStar(1,1)] = solver.matter.fdm_liquid.functions.HLLC(this, fPressureBoundary1, fDensityBoundary1, fFlowSpeedBoundary1, fInternalEnergyBoundary1,...
                        mVirtualPressure(1), mVirtualDensity(1), mFlowSpeed(1), mVirtualInternalEnergy(1), fTemperatureBoundary1, mVirtualTemperature(1));

                end

                if mCompCellPosition(end) == this.inCells && sum(mDeltaPressureComp(mCompCellPosition == this.inCells).*mDirectionDeltaPressureComp(mCompCellPosition == this.inCells)) < 0
                    [mGodunovFlux((this.inCells)+1,:), mMaxWaveSpeed((this.inCells)+1, 1), mPressureStar((this.inCells)+1,1)] = ...
                    solver.matter.fdm_liquid.functions.HLLC(this, mVirtualPressure(this.inCells), mVirtualDensity(this.inCells), mFlowSpeed(this.inCells), mVirtualInternalEnergy(this.inCells),...
                    fPressureBoundary2, fDensityBoundary2, fFlowSpeedBoundary2, fInternalEnergyBoundary2, mVirtualTemperature(end), fTemperatureBoundary2);

                else
                    [mGodunovFlux((this.inCells)+1,:), mMaxWaveSpeed((this.inCells)+1, 1), mPressureStar((this.inCells)+1,1)] = ...
                    solver.matter.fdm_liquid.functions.HLLC(this, mPressureWithoutLoss(this.inCells), mDensity(this.inCells), mFlowSpeed(this.inCells), mInternalEnergy(this.inCells),...
                    fPressureBoundary2, fDensityBoundary2, fFlowSpeedBoundary2, fInternalEnergyBoundary2, mTemperature(end), fTemperatureBoundary2);

                end
                
                for kGod = 1:1:(this.inCells)-1
                    if (sum(mDeltaPressureComp(mCompCellPosition == kGod).*mDirectionDeltaPressureComp(mCompCellPosition == kGod)) <= 0) && (sum(mDeltaPressureComp(mCompCellPosition == (kGod+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (kGod+1))) >= 0)
                        [mGodunovFlux(kGod+1,:), mMaxWaveSpeed(kGod+1), mPressureStar(kGod+1)] = solver.matter.fdm_liquid.functions.HLLC(this, mVirtualPressure(kGod), mDensity(kGod), mFlowSpeed(kGod), mInternalEnergy(kGod),...
                        mVirtualPressure(kGod+1), mVirtualDensity(kGod+1), mFlowSpeed(kGod+1), mVirtualInternalEnergy(kGod+1), mTemperature(kGod), mVirtualTemperature(kGod+1));

                    elseif (sum(mDeltaPressureComp(mCompCellPosition == kGod).*mDirectionDeltaPressureComp(mCompCellPosition == kGod)) > 0) && (sum(mDeltaPressureComp(mCompCellPosition == (kGod+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (kGod+1))) >= 0)
                        [mGodunovFlux(kGod+1,:), mMaxWaveSpeed(kGod+1), mPressureStar(kGod+1)] = solver.matter.fdm_liquid.functions.HLLC(this, mPressureWithoutLoss(kGod), mDensity(kGod), mFlowSpeed(kGod), mInternalEnergy(kGod),...
                        mVirtualPressure(kGod+1), mVirtualDensity(kGod+1), mFlowSpeed(kGod+1), mVirtualInternalEnergy(kGod+1), mTemperature(kGod), mVirtualTemperature(kGod+1));

                    elseif (sum(mDeltaPressureComp(mCompCellPosition == kGod).*mDirectionDeltaPressureComp(mCompCellPosition == kGod)) <= 0) && (sum(mDeltaPressureComp(mCompCellPosition == (kGod+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (kGod+1))) < 0)
                        [mGodunovFlux(kGod+1,:), mMaxWaveSpeed(kGod+1), mPressureStar(kGod+1)] = solver.matter.fdm_liquid.functions.HLLC(this, mVirtualPressure(kGod), mVirtualDensity(kGod), mFlowSpeed(kGod), mVirtualInternalEnergy(kGod),...
                        mPressureWithoutLoss(kGod+1), mDensity(kGod+1), mFlowSpeed(kGod+1), mInternalEnergy(kGod+1), mVirtualTemperature(kGod), mTemperature(kGod+1));

                    elseif (sum(mDeltaPressureComp(mCompCellPosition == kGod).*mDirectionDeltaPressureComp(mCompCellPosition == kGod)) > 0) && (sum(mDeltaPressureComp(mCompCellPosition == (kGod+1)).*mDirectionDeltaPressureComp(mCompCellPosition == (kGod+1))) < 0)
                        [mGodunovFlux(kGod+1,:), mMaxWaveSpeed(kGod+1), mPressureStar(kGod+1)] = solver.matter.fdm_liquid.functions.HLLC(this, mPressureWithoutLoss(kGod), mDensity(kGod), mFlowSpeed(kGod), mInternalEnergy(kGod),...
                        mPressureWithoutLoss(kGod+1), mDensity(kGod+1), mFlowSpeed(kGod+1), mInternalEnergy(kGod+1), mTemperature(kGod), mTemperature(kGod+1));
                    else
                        error('seems like one case was forgotten here')
                    end
                end
                
                %%
                %calculation of the Godunov Flux with the pressures set
                %correctly for the second Godunov Flux
                
                %before working on this section it is important to
                %understand how the fluxes influence each other because
                %this is somewhat counter intuitive for the second
                %component of the Godunov Flux. For example an increase of
                %one flux can overall mean a reduction of flow speed
                %because the acceleration on the fluid is decreased etc.

%at a cell k with the fluxes k and k+1 at the sides of the cell
%
%                  Flux k       Flux k+1
%                     ___________
%                    |           |
%                    |           |
%                    |   cell k  |
%                    |           |
%                    |___________|
%
%the acceleration on the fluid in the cell depends on the difference
%between the two fluxes. If flux k is higher than flux k+1 the acceleration
%is positive and the fluid will move in positive direction resulting in a
%positive flow rate. In the other case a negative acceleration and a
%negative flow rate will result. (please not that the momentum fluxes will
%never get negative because of their definition rho*u²+p) 
%But the absolut acceleration in both cases depends on the absolut 
%difference between the two fluxes which means that the further the two 
%fluxes differ from each other the higher the acceleration in either 
%direction will be. For this reason it is possible that a higher flux on 
%one side of the cell will result in a lower acceleration on the fluid in 
%the cell because the absolut difference between both fluxes will be 
%reduced. 
%Another important thing to notice is that the momentum fluxes do not
%depend on pressure differences like the mass fluxes but on absolut
%pressures either of the cell to the left/right or of the star region in
%the shock wave which is approximatly an average between those two. 
%
%Now with this knowledge the implementation of a processor that has an
%oriented pressure rise will be discussed: First since absolut pressures
%are represented in the momentum flux it is necessary to use the actual
%pressure from after the pump for the fluxes following it. However this
%means that the exit momentum flux of the cell would be larger than its
%entry flux. Therefore it is necessary to calculate a different entry flux
%that is higher than he exit flux of the cell. This can be achieved with
%the correct difference between the two fluxes by adding TWICE the pressure
%rise from the pump to the pressure at the entry to the pump. Since the
%exit flow of the cell before the one containing the pressure rise has to
%be smaller than the one entering the cell with the pressure jump it is
%necessary to calculate two different fluxes. One enters the next cell 
%( mMomentumGodunovFlux_k ) and one exits the current cell 
%( mMomentumGodunovFlux_k_1 )

                mMomentumGodunovFlux_k = zeros((this.inCells)+1, 3);
                mMomentumGodunovFlux_k_1 = zeros((this.inCells)+1, 3);
                
                for k = 1:this.inCells+1
                    if k == 1 && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) == 0)
                        [mMomentumGodunovFlux_k(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, fPressureBoundary1, fDensityBoundary1, fFlowSpeedBoundary1, fInternalEnergyBoundary1,...
                            mVirtualPressure(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k), fTemperatureBoundary1, mVirtualTemperature(k));
                        mMomentumGodunovFlux_k_1(k,:) = mMomentumGodunovFlux_k(k,:);
                        
                    elseif k == 1 && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) > 0)
                        [mMomentumGodunovFlux_k(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, fPressureBoundary1+2*sum(abs(mDeltaPressureComp(mCompCellPosition == k))), fDensityBoundary1, fFlowSpeedBoundary1, fInternalEnergyBoundary1,...
                            mVirtualPressure(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k), fTemperatureBoundary1, mVirtualTemperature(k));
                        mMomentumGodunovFlux_k_1(k,:) = mMomentumGodunovFlux_k(k,:);
                        
                    elseif k == 1 && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) < 0)
                        [mMomentumGodunovFlux_k(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, fPressureBoundary1, fDensityBoundary1, fFlowSpeedBoundary1, fInternalEnergyBoundary1,...
                            mPressureWithoutLoss(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k), fTemperatureBoundary1, mVirtualTemperature(k));
                        mMomentumGodunovFlux_k_1(k,:) = mMomentumGodunovFlux_k(k,:);
                        
                    elseif k == this.inCells+1 && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) == 0)
                        [mMomentumGodunovFlux_k(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, mVirtualPressure(k-1), mVirtualDensity(k-1), mFlowSpeed(k-1), mVirtualInternalEnergy(k-1),...
                            fPressureBoundary2, fDensityBoundary2, fFlowSpeedBoundary2, fInternalEnergyBoundary2, mVirtualTemperature(k-1), fTemperatureBoundary2);
                        mMomentumGodunovFlux_k_1(k,:) = mMomentumGodunovFlux_k(k,:);
                        
                  	elseif k == this.inCells+1 && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) > 0)
                        [mMomentumGodunovFlux_k(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, mPressureWithoutLoss(k-1), mVirtualDensity(k-1), mFlowSpeed(k-1), mVirtualInternalEnergy(k-1),...
                            fPressureBoundary2, fDensityBoundary2, fFlowSpeedBoundary2, fInternalEnergyBoundary2, mVirtualTemperature(k-1), fTemperatureBoundary2);
                        mMomentumGodunovFlux_k_1(k,:) = mMomentumGodunovFlux_k(k,:);
                        
                    elseif k == this.inCells+1 && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) < 0)
                        [mMomentumGodunovFlux_k(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, mVirtualPressure(k-1), mVirtualDensity(k-1), mFlowSpeed(k-1), mVirtualInternalEnergy(k-1),...
                            fPressureBoundary2+2*sum(abs(mDeltaPressureComp(mCompCellPosition == k))), fDensityBoundary2, fFlowSpeedBoundary2, fInternalEnergyBoundary2, mVirtualTemperature(k-1), fTemperatureBoundary2);
                        mMomentumGodunovFlux_k_1(k,:) = mMomentumGodunovFlux_k(k,:);
                        
                    elseif (sum(mDeltaPressureComp(mCompCellPosition == k-1).*mDirectionDeltaPressureComp(mCompCellPosition == k-1)) == 0) && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) == 0)
                        
                        mMomentumGodunovFlux_k(k,2) = mGodunovFlux(k,2);
                        mMomentumGodunovFlux_k_1(k,2) = mGodunovFlux(k,2);
                        
                    elseif (sum(mDeltaPressureComp(mCompCellPosition == k-1).*mDirectionDeltaPressureComp(mCompCellPosition == k-1)) == 0) && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) > 0)
                        [mMomentumGodunovFlux_k(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, mVirtualPressure(k-1)+2*sum(abs(mDeltaPressureComp(mCompCellPosition == k))), mVirtualDensity(k-1), mFlowSpeed(k-1), mVirtualInternalEnergy(k-1),...
                            mVirtualPressure(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k), mVirtualTemperature(k-1), mVirtualTemperature(k));
                        [mMomentumGodunovFlux_k_1(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, mVirtualPressure(k-1), mVirtualDensity(k-1), mFlowSpeed(k-1), mVirtualInternalEnergy(k-1),...
                            mVirtualPressure(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k), mVirtualTemperature(k-1), mVirtualTemperature(k));
                        
                    elseif (sum(mDeltaPressureComp(mCompCellPosition == k-1).*mDirectionDeltaPressureComp(mCompCellPosition == k-1)) > 0) && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) == 0)
                        [mMomentumGodunovFlux_k(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, mPressureWithoutLoss(k-1), mDensity(k-1), mFlowSpeed(k-1), mInternalEnergy(k-1),...
                            mVirtualPressure(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k), mTemperature(k-1), mVirtualTemperature(k));
                        
                        [mMomentumGodunovFlux_k_1(k,:)] = mMomentumGodunovFlux_k(k,:);
                        
                    elseif (sum(mDeltaPressureComp(mCompCellPosition == k-1).*mDirectionDeltaPressureComp(mCompCellPosition == k-1)) == 0) && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) < 0)
                        [mMomentumGodunovFlux_k(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, mPressureWithoutLoss(k-1), mDensity(k-1), mFlowSpeed(k-1), mInternalEnergy(k-1),...
                            mVirtualPressure(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k), mTemperature(k-1), mVirtualTemperature(k));
                        
                        [mMomentumGodunovFlux_k_1(k,:)] = mMomentumGodunovFlux_k(k,:);
                        
                    elseif (sum(mDeltaPressureComp(mCompCellPosition == k-1).*mDirectionDeltaPressureComp(mCompCellPosition == k-1)) < 0) && (sum(mDeltaPressureComp(mCompCellPosition == k).*mDirectionDeltaPressureComp(mCompCellPosition == k)) == 0)
                        [mMomentumGodunovFlux_k(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, mVirtualPressure(k-1), mVirtualDensity(k-1), mFlowSpeed(k-1), mVirtualInternalEnergy(k-1),...
                            mVirtualPressure(k), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k), mVirtualTemperature(k-1), mVirtualTemperature(k));
                        
                        [mMomentumGodunovFlux_k_1(k,:)] = solver.matter.fdm_liquid.functions.HLLC(this, mVirtualPressure(k-1), mVirtualDensity(k-1), mFlowSpeed(k-1), mVirtualInternalEnergy(k-1),...
                            mVirtualPressure(k)+2*sum(abs(mDeltaPressureComp(mCompCellPosition == k-1))), mVirtualDensity(k), mFlowSpeed(k), mVirtualInternalEnergy(k), mVirtualTemperature(k-1), mVirtualTemperature(k));
                        
                    else
                        error('active pressure influencing components have to be seperated by at least one cell to the left and right.\n Therefore check the overall setup of your system and increase the number of cells.')
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
                %calculation of the flow speeds at the cell boundaries
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
                
                %For some systems there is a stability limit how far the 
                %courant number may be increased. Therefore in case
                %instabilities are detected the courant number is reduced a
                %bit and the adaption is stopped. However this a not a
                %foolproof algorithm and the adaption may still lead to
                %instabilities.
                if this.sCourantAdaption.bAdaption == 1 && (this.oBranch.oContainer.oTimer.iTick > 10000)
                    for k = 1:this.inCells
                        if ((sign(this.mPressureOld(k)-this.mPressureOld1(k)) ~= sign(this.mPressureOld1(k)-this.mPressureOld2(k))) && (sign(this.mPressureOld1(k)-this.mPressureOld2(k)) ~= sign(this.mPressureOld2(k)-this.mPressureOld3(k))) && (abs(this.mPressureOld(k)-this.mPressureOld1(k)) > this.fMaxPressureDifference*10^-5))
                            this.sCourantAdaption.bAdaption = 0; 
                        end
                    end
                end
                
                %increases the courant number by a factor or sets it to one
                %if its value is already 0.9999
                if this.sCourantAdaption.bAdaption == 1 && this.sCourantAdaption.iTimeStepAdaption >= 0 && this.fCourantNumber < 0.9999*this.sCourantAdaption.fMaxCourantNumber && this.oBranch.oContainer.oTimer.iTick > this.sCourantAdaption.iInitialTicks && mod(this.oBranch.oContainer.oTimer.iTick, this.sCourantAdaption.iTicksBetweenIncrease) == 0
                    this.fCourantNumber = this.fCourantNumber*this.sCourantAdaption.fIncreaseFactor;
                elseif this.sCourantAdaption.bAdaption == 1 && this.sCourantAdaption.iTimeStepAdaption >= 0 && this.fCourantNumber >= 0.9999*this.sCourantAdaption.fMaxCourantNumber && this.oBranch.oContainer.oTimer.iTick > this.sCourantAdaption.iInitialTicks && mod(this.oBranch.oContainer.oTimer.iTick, this.sCourantAdaption.iTicksBetweenIncrease) == 0
                    this.fCourantNumber = this.sCourantAdaption.fMaxCourantNumber;
                end
                
                %if instabilities were detected in the previous time step
                %the courant number is decreased again and the adaption is
                %completly halted.
                if this.sCourantAdaption.bAdaption == 0
                    this.fCourantNumber = this.fCourantNumber/(this.sCourantAdaption.fIncreaseFactor^100);
                    this.sCourantAdaption.bAdaption = 2;
                end
                
                %%
                %a while loop either keeps iterating until the values for
                %the pressure are not negative or till an error occurs.
                %Generally if negative pressures are detected the loop is
                %only allowed to run one more time with a decreased courant
                %number and if that also leads to negative results it will
                %abort calculation and return an error.
                
                %initilization values that are only required to get the
                %while loop into its first iteration.
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
                    
                    mStateVectorNew(k,2) = mStateVector(k,2)+(fTimeStep/fCellLength)*(mMomentumGodunovFlux_k(k,2)-mMomentumGodunovFlux_k_1(k+1,2));
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
                %implementation of the pressure loss as a flow speed loss 
                %using F=m*a and then integrating the acceleration 
                %(assuming it is constant over the timestep) leads to an
                %equation for a reduced in flow speed:
                % (p*delat_t)/(rho*L)
                this.mFlowSpeedLoss = zeros(this.inCells,1);
                this.mPressureLoss = zeros(this.inCells,1);
                
                %writing the pressure and flow speed loss to the branch
                %object is only necessary to be able to plot them. It is
                %not used in any way for the calculation.
                for k = 1:this.inCells
                    this.mPressureLoss(k) = mTotalPressureLossCell(k);

                    this.mFlowSpeedLoss(k) = (this.mPressureLoss(k)*fTimeStep)/(mDensityNew(k)*fCellLength); 
                    if abs(mFlowSpeedNew(k)) <= abs(this.mFlowSpeedLoss(k))
                        mFlowSpeedNew(k) = 0;
                    elseif mFlowSpeedNew(k) > 0
                        mFlowSpeedNew(k) = mFlowSpeedNew(k)-this.mFlowSpeedLoss(k);
                    elseif mFlowSpeedNew(k) < 0
                        mFlowSpeedNew(k) = mFlowSpeedNew(k)+this.mFlowSpeedLoss(k);
                    end
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
                %branch in V-HAB which was one condition for the solver.     
                fMassFlow = sum(mMassFlow)/(this.inCells);
                
                %%
                %calculates the new cell temperatures from the first law of
                %thermodynamics. This is not done by the internal energy
                %that is part of the godunov fluxes because a correct
                %equation for the internal energy of liquids was missing
                %which lead to errors in the calculation.
                
                %TO DO: If temp dependent heat capacity is introduced this
                %section has to be reworked. At the moment the heat capcity
                %here is assumed constant which is why it can be
                %disregarded
                
                %the calculation is based upon the principle that the
                %ingoing fluxes use the actual temperature with proc
                %influence from the neighboring cells while the outgoing
                %fluxes use the virtual temperature without the temp
                %influence of the procs in the cell itself.
                if mGodunovFlux(1,1) >= 0 && mGodunovFlux(2,1) >= 0
                	mVirtualTemperatureNew(1) = ((mVirtualTemperature(1)-fTempRef)*fCellLength*mDensity(1)+(mGodunovFlux(1,1)*(fTemperatureBoundary1-fTempRef)-mGodunovFlux(2,1)*(mVirtualTemperature(1)-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(1))+fTempRef;
                elseif mGodunovFlux(1,1) < 0 && mGodunovFlux(2,1) < 0
                    mVirtualTemperatureNew(1) = ((mVirtualTemperature(1)-fTempRef)*fCellLength*mDensity(1)+(mGodunovFlux(1,1)*(mVirtualTemperature(1)-fTempRef)-mGodunovFlux(2,1)*(mTemperature(2)-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(1))+fTempRef;
                elseif mGodunovFlux(1,1) >= 0 && mGodunovFlux(2,1) < 0
                    mVirtualTemperatureNew(1) = ((mVirtualTemperature(1)-fTempRef)*fCellLength*mDensity(1)+(mGodunovFlux(1,1)*(fTemperatureBoundary1-fTempRef)-mGodunovFlux(2,1)*(mTemperature(2)-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(1))+fTempRef;
                elseif mGodunovFlux(1,1) < 0 && mGodunovFlux(2,1) >= 0
                    mVirtualTemperatureNew(1) = ((mVirtualTemperature(1)-fTempRef)*fCellLength*mDensity(1)+(mGodunovFlux(1,1)*(mVirtualTemperature(1)-fTempRef)-mGodunovFlux(2,1)*(mVirtualTemperature(1)-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(1))+fTempRef;
                end
                
                if mGodunovFlux(end-1,1) >= 0 && mGodunovFlux(end,1) >= 0
                	mVirtualTemperatureNew(end) = ((mVirtualTemperature(end)-fTempRef)*fCellLength*mDensity(end)+(mGodunovFlux(end-1,1)*(mTemperature(end-1)-fTempRef)-mGodunovFlux(end,1)*(mVirtualTemperature(end)-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(end))+fTempRef;
                elseif mGodunovFlux(end-1,1) < 0 && mGodunovFlux(end,1) < 0
                    mVirtualTemperatureNew(end) = ((mVirtualTemperature(end)-fTempRef)*fCellLength*mDensity(end)+(mGodunovFlux(end-1,1)*(mVirtualTemperature(end)-fTempRef)-mGodunovFlux(end,1)*(fTemperatureBoundary2-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(end))+fTempRef;
                elseif mGodunovFlux(end-1,1) >= 0 && mGodunovFlux(end,1) < 0
                    mVirtualTemperatureNew(end) = ((mVirtualTemperature(end)-fTempRef)*fCellLength*mDensity(end)+(mGodunovFlux(end-1,1)*(mTemperature(end-1)-fTempRef)-mGodunovFlux(end,1)*(fTemperatureBoundary2-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(end))+fTempRef;
                elseif mGodunovFlux(end-1,1) < 0 && mGodunovFlux(end,1) >= 0
                    mVirtualTemperatureNew(end) = ((mVirtualTemperature(end)-fTempRef)*fCellLength*mDensity(end)+(mGodunovFlux(end-1,1)*(mVirtualTemperature(end)-fTempRef)-mGodunovFlux(end,1)*(mVirtualTemperature(end)-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(end))+fTempRef;
                end
                
                for k = 2:(this.inCells-1)
                    if mGodunovFlux(k,1) >= 0 && mGodunovFlux(k+1,1) >= 0
                        mVirtualTemperatureNew(k) = ((mVirtualTemperature(k)-fTempRef)*fCellLength*mDensity(k)+(mGodunovFlux(k,1)*(mTemperature(k-1)-fTempRef)-mGodunovFlux(k+1,1)*(mVirtualTemperature(k)-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(k))+fTempRef;
                    elseif mGodunovFlux(k,1) < 0 && mGodunovFlux(k+1,1) < 0
                        mVirtualTemperatureNew(k) = ((mVirtualTemperature(k)-fTempRef)*fCellLength*mDensity(k)+(mGodunovFlux(k,1)*(mVirtualTemperature(k)-fTempRef)-mGodunovFlux(k+1,1)*(mTemperature(k+1)-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(k))+fTempRef;
                    elseif mGodunovFlux(k,1) >= 0 && mGodunovFlux(k+1,1) < 0
                        mVirtualTemperatureNew(k) = ((mVirtualTemperature(k)-fTempRef)*fCellLength*mDensity(k)+(mGodunovFlux(k,1)*(mTemperature(k-1)-fTempRef)-mGodunovFlux(k+1,1)*(mTemperature(k+1)-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(k))+fTempRef;
                    elseif mGodunovFlux(k,1) < 0 && mGodunovFlux(k+1,1) >= 0
                        mVirtualTemperatureNew(k) = ((mVirtualTemperature(k)-fTempRef)*fCellLength*mDensity(k)+(mGodunovFlux(k,1)*(mVirtualTemperature(k)-fTempRef)-mGodunovFlux(k+1,1)*(mVirtualTemperature(k)-fTempRef))*fTimeStep)/(fCellLength*mDensityNew(k))+fTempRef;
                    end
                end
                
                for k = 1:this.inCells
                    mTemperatureNew(k) = mVirtualTemperatureNew(k) + sum(mDeltaTempComp(mCompCellPosition == k));
                end
                
                %%
                %Pressure is calculated using the matter table
                for k=1:1:this.inCells
                    %TODO Replace this with a calculatePressure() method in the
                    %matter table that takes all contained substances into account,
                    %not just water.
                    tParameters = struct();
                    tParameters.sSubstance = 'H2O';
                    tParameters.sProperty = 'Pressure';
                    tParameters.sFirstDepName = 'Density';
                    tParameters.fFirstDepValue = mDensityNew(k);
                    tParameters.sPhaseType = 'liquid';
                    tParameters.sSecondDepName = 'Temperature';
                    tParameters.fSecondDepValue = mTemperatureNew(k);
                    tParameters.bUseIsobaricData = true;
                    
                    mPressureNew(k) = this.oBranch.oContainer.oData.oMT.findProperty(tParameters);
                end
                %%
                %calculation of the virtual cell values

                %from the fluxes the new virtual densities are calculated
                for k = 1:this.inCells
                    mVirtualDensityNew(k) = mVirtualDensity(k) + (fTimeStep/fCellLength)*(mGodunovFlux(k,1)-mGodunovFlux(k+1,1));
                end
                
                %using the new virtual density and temperature the new
                %internal energy can be calculated as well as the virtual
                %pressure.
                for k = 1:this.inCells
                    mVirtualInternalEnergyNew(k) = mVirtualDensityNew(k)*(0.5*mFlowSpeed(k)^2+fHeatCapacity*(mVirtualTemperatureNew(k)-fTempRef));
                    %TODO Replace this with a calculatePressure() method in the
                    %matter table that takes all contained substances into account,
                    %not just water.
                    tParameters = struct();
                    tParameters.sSubstance = 'H2O';
                    tParameters.sProperty = 'Pressure';
                    tParameters.sFirstDepName = 'Density';
                    tParameters.fFirstDepValue = mVirtualDensityNew(k);
                    tParameters.sPhaseType = 'liquid';
                    tParameters.sSecondDepName = 'Temperature';
                    tParameters.fSecondDepValue = mVirtualTemperatureNew(k);
                    tParameters.bUseIsobaricData = true;
                    
                    mVirtualPressureNew(k) = this.oBranch.oContainer.oData.oMT.findProperty(tParameters);
                end
                
                %%
                %this section decreases the time step again if the previous
                %increase lead to negative pressures
                
                %in case the pressure is still negative after reducing the
                %courant number again the solver will abort calculation and
                %return an error
                if this.sCourantAdaption.iTimeStepAdaption < 0 && (min(mPressureNew) < 0 || min(mVirtualPressure) < 0)
                    string = sprintf('negative pressure occured in the solver!\n First try decreasing the Courant Number of the Branch if this does not help see list of other possible errors:\n -the number of cells for the branch is too low \n -the diameter of the pipes is large compared to the volume of a tank \n -the pressures set in the system are wrong (e.g. a pump that has a too high pressure jump) \n -the system is subjected to excessiv cooling');
                    error(string)
                end
                
                %if negative pressures are detected for the first time the
                %courant number is reduced again to the previous level and
                %the whole calculation is redone. Setting the
                %iTimeStepAdaption variable will prevent a new increase of
                %the courant number for the next 1000 ticks
                if (min(mPressureNew) < 0 || min(mVirtualPressure) < 0) && this.fCourantNumber ~= this.sCourantAdaption.fMaxCourantNumber
                    this.fCourantNumber = this.fCourantNumber/this.sCourantAdaption.fIncreaseFactor;
                    this.sCourantAdaption.iTimeStepAdaption = -1000;
                elseif (min(mPressureNew) < 0 || min(mVirtualPressure) < 0)
                    this.fCourantNumber = 0.9999*this.sCourantAdaption.fMaxCourantNumber;
                    this.sCourantAdaption.iTimeStepAdaption = -1000;
                end
            
                %end of the while loop
                end
                
                %increases the variable iTimeStepAdaption by one for each
                %solver tick and if the value is positive again the solver
                %is allowed to increase the courant number again
                if this.sCourantAdaption.iTimeStepAdaption < 0
                    this.sCourantAdaption.iTimeStepAdaption = this.sCourantAdaption.iTimeStepAdaption+1;
                end

                %%
                %calculates the temperature and pressure for the flows and
                %from these values the delta vectors required by the base
                %branch are derived.
                
                afPressure = zeros(iNumberOfProcs,1);
                afTemperatures = zeros(iNumberOfProcs,1);
                mFlowTemp = zeros(length(this.oBranch.aoFlows),1);
                mFlowPressure = zeros(length(this.oBranch.aoFlows),1);
          
                %the difficulty when calculating the flow values is that
                %multiple components may be placed in the same cell. If 
                %only the cell values was used for the flows all the flows
                %between those components would have the same values which
                %is wrong. Therefore it is necessary to take the cell value
                %and then subtract all the influences of processors the
                %fluid has not already passed. This again means that the
                %calculation has to be dependent on the flow direction in
                %the branch.
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
                %decrease, negative an increase!
                for k = 1:iNumberOfProcs
                    afTemperatures(k) = mFlowTemp(k)-mFlowTemp(k+1);
                    afPressure(k) = mFlowPressure(k)-mFlowPressure(k+1);
                end

                %%
                %sets some values as object parameters in order to decide
                %when calculation can be assumed as finished
                
                %writes values for the massflow into the object parameters
                %to decide in the next step wether further numeric
                %calculation is required
                if strcmp(this.mMassFlowOld, 'empty')
                    this.mMassFlowOld = zeros(5000,1);
                end
                
                for k = 2:5000
                   this.mMassFlowOld(k) = this.mMassFlowOld(k-1);
                end
                
                this.mMassFlowOld(1) = fMassFlow;
                
                if this.fMaxPressureDifference < abs(fPressureBoundary1WithProcs-fPressureBoundary2WithProcs)
                    this.fMaxPressureDifference = abs(fPressureBoundary1WithProcs-fPressureBoundary2WithProcs);
                end 
                
                fAverageMassFlow1 = sum(this.mMassFlowOld(1:2500))/length(this.mMassFlowOld(1:2500));
                fAverageMassFlow2 = sum(this.mMassFlowOld(2501:5000))/length(this.mMassFlowOld(2501:5000));
                
                fAverageMassFlowDiff = fAverageMassFlow1-fAverageMassFlow2;
                
                %if the difference between the average massflow of the last
                %100 time steps and the averagev massflow of the 100 
                %timesteps before that is less than the residual target 
                %the counter for the number of times this has happened in a
                %row is increased
                if  this.fMassFlowResidualFactor ~= 0 && this.oBranch.oContainer.oTimer.iTick > 1000 && mod(this.oBranch.oContainer.oTimer.iTick,1000) == 0 && (abs(fAverageMassFlowDiff) < this.fMassFlowResidualFactor)
                    this.iMassFlowResidualCounter = this.iMassFlowResidualCounter+1;
                elseif this.iMassFlowResidualCounter ~= 0 && this.oBranch.oContainer.oTimer.iTick > 1000 && mod(this.oBranch.oContainer.oTimer.iTick,1000) == 0 && (abs(fAverageMassFlowDiff) > this.fMassFlowResidualFactor)
                    %resets the counter to 0 if the target is no longer
                    %reached
                    this.iMassFlowResidualCounter = 0;
                end
                 
                %if the difference between the two boundary pressures is
                %smaller than the initial pressure multiplied with the
                %residual target the counter for how often this has
                %happened in a row is increased.
                if this.fPressureResidualFactor ~= 0 && ~strcmp(this.fMaxPressureDifference, 'empty') && (abs(fPressureBoundary1-fPressureBoundary2) < this.fMaxPressureDifference*this.fPressureResidualFactor)
                    this.iPressureResidualCounter = this.iPressureResidualCounter+1;
                elseif this.iPressureResidualCounter ~= 0 && (abs(fPressureBoundary1-fPressureBoundary2) > this.fMaxPressureDifference*this.fPressureResidualFactor)
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
                
                %This part is only necessary if cell values are of interest
                %and should be plotted
                metaaoLiquidBranch = findprop((this.oBranch.oContainer), 'aoLiquidBranch');
                if ~isempty(metaaoLiquidBranch)
                    for k = 1:length(this.oBranch.oContainer.aoBranches)
                        if strcmp(this.oBranch.sName, this.oBranch.oContainer.aoBranches(k).sName)
                            this.oBranch.oContainer.aoLiquidBranch{k} = this;
                        end
                    end
                end
                
                %if the solver had already reached a steady state the
                %solver still calculates one complete loop every 0.1s. For
                %this purpose this variable tells the solver that the
                %steady state had been reached and the loop has been
                %calculated.
                if this.iSteadyState >= 100
                    this.iSteadyState = 1;
                end
                
                %finally sets the time step for the branch as well as the
                %mass flow rate
                
                %sets the timestep from this branch for the base branch
                this.setTimeStep(fTimeStep);
                
                %tells the stores when to update
%                 this.oBranch.coExmes{1, 1}.oPhase.oStore.setNextExec(this.oBranch.oContainer.oTimer.fTime+fTimeStep);
%                 this.oBranch.coExmes{2, 1}.oPhase.oStore.setNextExec(this.oBranch.oContainer.oTimer.fTime+fTimeStep);
                %calls the update for the base branch using the newly
                %calculated mass flow
                %branch(this, fFlowRate, afPressures, afTemperatures)
                update@solver.matter.base.branch(this, fMassFlow, afPressure);
                
                for k = 1: length(this.oBranch.aoFlowProcs)
                    this.oBranch.aoFlowProcs(1,k).update();
                end
                
            end
        end
    end
end
