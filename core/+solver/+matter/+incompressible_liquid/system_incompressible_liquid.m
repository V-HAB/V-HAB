classdef system_incompressible_liquid
%% System Solver for incompressible liquid flow problems
%while the solver is intended for liquid flow problems it actually also
%works for gas flows. However if it is used with gas flows the solver will
%be subjected to instabilities if the time step gets too large and the
%timestep has to be chosen much smaller than it would be necessary for a
%liquid flow problem
%
%Also even if it says system solver it is possible to use other solvers in
%the same system as well. In that case you simply have to define all
%branches which are supposed to be calculated by this system solver before
%all the other branches and set the input value for the last system branch
%to the number of the last branch you want this system solver to calculate.
%The number of the branches are simply given in the order you define them
%in your system so the first branch you define will be number one and so
%on. For all other branches you can use the other solvers as you like, as
%long as the values you generate with these solvers don't have a negative
%influence on this solver. (For example if you put a manual solver with a
%very high oscillation at the same phase where branch for this system
%solver leaves, the system solver branch will also oscillate and never
%reach steady state conditions which makes the computation very slow)
%
%%%%%%%%%%%%%%%%%%%%Tipps to get Faster Simulations:%%%%%%%%%%%%%%%%%%%%%%%
%
%this solver uses a steady state identification which means that the system
%has reached a steady state the solver uses a large time step. If you want
%to run simulation very quickly you should try to get into this steady
%state as quick as possible. This can be achieved by choosing the inital
%conditions close to the steady state conditions of the system. If you
%don't know the steady state conditions for your system that isn't a
%problem. Just let your system run once with some initial conditions and
%look at the plots to find the steady state values. Of course if you have
%defined initial conditions this might not help for the final simulation
%but you can at least cut the time require for the simulation while
%debugging by quite a bit.
%
%Another option is to increase the minimum time step and the maximum
%allowed flow speed change. But you have to be careful while changing these
%values because the solver might become instable. If it does become
%instable you'll have increasing oscillations of the mass flow in at least
%one branch calculated by this solver and that is a definite sign that you
%should decrease the values again. It is a bit of trial and error to find
%the best values for these two but it may be worth the effort if you have
%to run a lot of simulations for your system.

    properties (SetAccess = protected, GetAccess = public)
        
        %contains the V-HAB system for which this solver is providing the
        %mass flows
        oSystem;
        
        %the mass flow of the previous timesteps is saved in this variable
        mMassFlowOld; %kg/s
        
        %the acceleration in the branches for the previous timesteps is
        %saved in this variable
        mAccelerationOld; %m/s^2
        
        %Number of the old steps that are taken into account in the
        %calculations for averaging and deciding on steady state
        iNumberOfOldSteps = 10;
        
        %procentual maximum allowed flow speed change in one time step. The
        %actual changes may be higher or lower because after time step
        %calculation a predictor corrector calculation is used to adapt the
        %values. An iterative calculation would be more accurate but also
        %require more computations.
        fMaxProcentualFlowSpeedChange = 1e-3;
        
        %number of internal partial time steps within the solver
        iPartSteps = 10;
        
        %contains the values for the last calculated mass flows for each
        %branch of the system solver. They are in the same order as the
        %branches in the aoBranch object of the V-HAB system
        mMassFlow;
        
        %number of branches this solver has to calculate
        iNumberOfBranches;
        %number of phases that are connected to the calculated branches
        iNumberOfPhases;
        %the number of flow processors inside each branch. This is actually
        %a vector containing the number of procs for the respective branch
        %in the same order as the branches are defined in the aoBranch
        %object of the parent system
        iNumberOfProcs;
        
        %cell array containing the names of the phases adjacent to
        %branches. Note that each phase is required to have a unique name
        %for this solver to work!
        cPhaseNames;
        %struct that has the phase names as fields and the respective store
        %names as field values.
        tStoreNames;
        
        %A Matrix with the phasename of the left (1st column) and right (2nd
        %column) side of each branch (row)
        cPhaseNameMatrix;
        
        %struct containing the conectivity matrices for each store. The
        %store names are the field names of the struct and the matrix is
        %the field value.
        %The conectivity matrix is calculated by the solver once and then
        %stored in this variable. For each store it is a matrix with the dimension
        %(iNumberOfBranches,2) and the first column is used if the store is
        %on the left hand of the branch while the second column is used if
        %the store is on the right hand side. For each row the respective
        %value is one if this store is used in the branch at that position.
        %Obviously one store may be boundary to more than one branch and
        %this matrix allows the predictor corrector scheme to predict the
        %new store masses more accuratly.
        sConectivityMatrix;
        
        
        %the last time at which this solver was executed
        fLastExec = 0;
        %the next time this solver will be exectued
        fNextExec = 0;
        
        %timestep used for the solver. This will be calculated during the
        %solution process.
        fTimeStepSystem = 1e-8;
        
        %minimal time step of the system solver. May be defined by the user
        fMinTimeStep = 1e-8;
        %maximum time step of the system solver. May be defined by the user
        fMaxTimeStep = 60;
        
        %cell array containing the direction in which restrictor valves
        %let fluid pass or the entry 0 if the flow proc is not a restrictor
        %valve. Each cell field stand for one branch
        cRestrictorValve;
        
        %boolean variable to decide if the system has reached steady state
        bSteadyState = false;
        %counter for the number of times the steady state condition has
        %been reached. After it reaches 10 the system assumes steady state
        iSteadyStateCounter = 0;
        
        %bunch of old values
        mPhasePressuresOld;
        mDeltaPressureCompsTotalOld;
        mPressureLossOld;
        mDeltaTempCompsTotalOld;
        mMinHydrDiamOld;
        mFlowSpeedOld;
        
        mTimeOld;
        
        %% branch variables
        %these are variables saved as properties only because they are also
        %used by each individual incompressible liquid branch. This way it
        %is not necessary for each branch to calculate the values again but
        %it can just use the ones provided by the system solver.
        
        %overall value of the hydraulic length for each branch
        mBranchLength;
        %inverse value of the overall hydraulic length of each branch
        mInverseBranchLength;
        %the area for each branch calculated by using the smallest
        %hydraulic diameter found in the system
        mBranchArea;
        %density of the fluid inside each branch. (even if temperature
        %changing flow procs are used the solver assumes a constant density
        %over the branch because of incompressibility. The density and 
        %temperature over the flow procs are provided by the individual branch) 
        mBranchDensities;
        
        %again a matrix with the dimension (iNumberOfBranches,2) containing
        %the pressure of the store on the left and right hand side of each
        %branch
        mPhasePressures;
        %overall pressure generated by components inside the branch
        mDeltaPressureCompsTotal;
        %overall pressure loss from all components inside the branch
        mPressureLoss;
        %overall temperature difference created by all components inside
        %the branch (not used in the system solver but in each individual
        %branch)
        mDeltaTempCompsTotal;
        %smallest hydraulic diameter within each branch
        mMinHydrDiam;
        
        %cell array containing a vector with the individual delta pressures
        %of each component in the branch with the same number as the cell
        %field number
        cDeltaPressureComp;
        %cell array containing a vector with the individual delta temperatures
        %of each component in the branch with the same number as the cell
        %field number
        cDeltaTempComp;
        %cell array containing a vector with the individual pressure losses
        %of each component in the branch with the same number as the cell
        %field number
        cPressureLossComp;
        
        %counter how often the iteration was executed in the solver
        iCounter;
        
        
        %% Steady State System Properties
        %matrix that contains one column for each independent loop in the
        %system. The column contains the respective branch numbers for this
        %loop
        mLoopBranches;
        fSteadyStateTimeStep;
    end

    methods 
        %%
        %definition of the branch and the possible input values.
        %For explanation about the values see initial comment section.
        function this = system_incompressible_liquid(oSystem, fMinTimeStep, fMaxTimeStep, fMaxProcentualFlowSpeedChange, iPartialSteps, iLastSystemBranch, fSteadyStateTimeStep, mLoopBranches)  
            
            %sets the parent system for which the system solver provides
            %mass flow calculations
            this.oSystem = oSystem;
            
            %decides which branch should be the last one the system solver
            %calculates
            this.iNumberOfBranches = iLastSystemBranch;
            
            this.fSteadyStateTimeStep = fSteadyStateTimeStep;
            if nargin == 8
                this.mLoopBranches = mLoopBranches;
            end
        
            
            for k = 1:this.iNumberOfBranches
                this.cPhaseNameMatrix{k,1} = this.oSystem.aoBranches(k).coExmes{1,1}.oPhase.sName;
                this.cPhaseNameMatrix{k,2} = this.oSystem.aoBranches(k).coExmes{2,1}.oPhase.sName;
                
                if isfield(this.tStoreNames, this.oSystem.aoBranches(k).coExmes{1,1}.oPhase.sName)
                    if ~strcmp(this.tStoreNames.(this.oSystem.aoBranches(k).coExmes{1,1}.oPhase.sName),this.oSystem.aoBranches(k).coExmes{1,1}.oPhase.oStore.sName)
                        error('for the incompressible system solver each phase needs to have a unique name (no two phases having the same name even if they are in different stores)')
                    end
                else
                    this.tStoreNames.(this.oSystem.aoBranches(k).coExmes{1,1}.oPhase.sName) = this.oSystem.aoBranches(k).coExmes{1,1}.oPhase.oStore.sName;
                end
                
                if isfield(this.tStoreNames, this.oSystem.aoBranches(k).coExmes{2,1}.oPhase.sName)
                    if ~strcmp(this.tStoreNames.(this.oSystem.aoBranches(k).coExmes{2,1}.oPhase.sName),this.oSystem.aoBranches(k).coExmes{2,1}.oPhase.oStore.sName)
                        error('for the incompressible system solver each phase needs to have a unique name (no two phases having the same name even if they are in different stores)')
                    end
                else
                    this.tStoreNames.(this.oSystem.aoBranches(k).coExmes{2,1}.oPhase.sName) = this.oSystem.aoBranches(k).coExmes{2,1}.oPhase.oStore.sName;
                end
            end
            
            this.cPhaseNames = cell(1,1);
            for k = 1:this.iNumberOfBranches
                sPhaseNameLeft = this.cPhaseNameMatrix{k,1};
                sPhaseNameRight = this.cPhaseNameMatrix{k,2};
                
                if length(this.cPhaseNames) == 1
                    this.cPhaseNames{1,1} = sPhaseNameLeft;
                    this.cPhaseNames{2,1} = sPhaseNameRight;
                else
                    bLeftPhaseNameExists = false;
                    bRightPhaseNameExists = false;
                    for l = 1:length(this.cPhaseNames)
                        if strcmp(this.cPhaseNames{k,1}, sPhaseNameLeft)
                            bLeftPhaseNameExists = true;
                        elseif strcmp(this.cPhaseNames{k,1}, sPhaseNameRight)
                            bRightPhaseNameExists = true;
                        end
                    end
                    if bLeftPhaseNameExists ~= 1
                        this.cPhaseNames{end+1,1} = sPhaseNameLeft;
                    end
                    if bRightPhaseNameExists ~= 1
                        this.cPhaseNames{end+1,1} = sPhaseNameRight;
                    end
                end
            end
            
            this.iNumberOfPhases = length(this.cPhaseNames);
            
            this.mMassFlow = zeros(this.iNumberOfBranches,1);
            this.mMassFlowOld = zeros(this.iNumberOfBranches,this.iNumberOfOldSteps);
            this.mFlowSpeedOld = zeros(this.iNumberOfBranches,1);
            this.mAccelerationOld = zeros(this.iNumberOfBranches,this.iNumberOfOldSteps);
            this.mTimeOld = zeros(1,this.iNumberOfOldSteps);
            
            this.fMinTimeStep = fMinTimeStep;
            this.fMaxTimeStep = fMaxTimeStep;
            
            this.fMaxProcentualFlowSpeedChange = fMaxProcentualFlowSpeedChange;
            this.iPartSteps = iPartialSteps;
            %Each entry of the mInverseBranchLength vector contains the inverse
            %value of the overall length of all components of the
            %respective branch
            this.mInverseBranchLength = zeros(this.iNumberOfBranches,1);
            %Each entry of the mInverseBranchLength vector contains the
            %value of the branch area (it is assumed that the branch as an
            %overall equal area and if not the minimal are is used)
            this.mBranchArea = zeros(this.iNumberOfBranches,1);
            
            this.iNumberOfProcs = zeros(this.iNumberOfBranches,1);
            
            for k = 1:this.iNumberOfBranches
                this.iNumberOfProcs(k) = length(oSystem.aoBranches(k).aoFlowProcs);
            end
            
            this.cRestrictorValve = cell(this.iNumberOfBranches,1);
            for k = 1:this.iNumberOfBranches
                
                %the meta values are used to decide whether a component even
                %has the respective attribute because not necessarily all
                %components have alle the attributes
                
                fDiameter = inf;
                mLength = zeros(this.iNumberOfProcs(k),1);
                this.cRestrictorValve{k} = zeros(this.iNumberOfProcs(k),1);
                
                for m = 1:this.iNumberOfProcs(k)
                    %if the processor with index k has the respective property
                    %its value is written into the respective vector. If not
                    %the vector entry remains zero or for the diameter -1.
                    if isprop(oSystem.aoBranches(k).aoFlowProcs(1,m), 'fHydrDiam')
                        if (oSystem.aoBranches(k).aoFlowProcs(1,m).fHydrDiam < fDiameter) && (oSystem.aoBranches(k).aoFlowProcs(1,m).fHydrDiam > 0)
                            fDiameter = oSystem.aoBranches(k).aoFlowProcs(1,m).fHydrDiam;
                        end
                    elseif isprop(oSystem.aoBranches(k).aoFlowProcs(1,m), 'fDiameter')
                        if (oSystem.aoBranches(k).aoFlowProcs(1,m).fDiameter < fDiameter) && (oSystem.aoBranches(k).aoFlowProcs(1,m).fDiameter > 0)
                            fDiameter = oSystem.aoBranches(k).aoFlowProcs(1,m).fDiameter;
                        end
                    end
                    if isprop(oSystem.aoBranches(k).aoFlowProcs(1,m), 'fHydrLength')
                        mLength(m) = oSystem.aoBranches(k).aoFlowProcs(1,m).fHydrLength;
                    elseif isprop(oSystem.aoBranches(k).aoFlowProcs(1,m), 'fLength')
                        mLength(m) = oSystem.aoBranches(k).aoFlowProcs(1,m).fLength;
                    end
                    
                    if ~isempty(regexp(oSystem.aoBranches(k).aoFlowProcs(1,m).oMeta.Name, 'unidirectional_restrictor_valve', 'once'))
                        this.cRestrictorValve{k}(m) = oSystem.aoBranches(k).aoFlowProcs(1,m).iDirection;
                    else
                        this.cRestrictorValve{k}(m) = 0;
                    end
                    
                end
                fBranchLength = sum(mLength);
                this.mInverseBranchLength(k) = 1/fBranchLength;
                this.mBranchArea(k) = fDiameter^2*pi*0.25;
            end
           
            %calculates the conectivity matric for each phase. The
            %conectivity matrix contains a row for each branch and two
            %columns for the left and right side of each branch. If this
            %phase is present at any of these locations the respective
            %entry is one
            this.sConectivityMatrix = struct();
            for m = 1:this.iNumberOfPhases
                 this.sConectivityMatrix.(this.cPhaseNames{m,1}) = (strcmp(this.cPhaseNameMatrix, this.cPhaseNames{m,1})) ;
            end
            
            
        end
    end
    
    methods (Access = public)
        
        function update(this)
            
        %only calculate the system if has not already been calculated at 
        %this time. Otherwise it would be calculated by each branch, since
        %each individual branch calls for an update
        if (this.fLastExec < this.oSystem.oTimer.fTime) || this.oSystem.oTimer.fTime == 0
            %For the following vector definition the vector entries are
            %always associated to one branch. E.G. the first entry is
            %associated to the branch aoBranches(1) and the second one to
            %aoBranches(2) and so on.

            this.mDeltaPressureCompsTotal = zeros(this.iNumberOfBranches,1);
            this.mDeltaTempCompsTotal = zeros(this.iNumberOfBranches,1);
            this.mPressureLoss = zeros(this.iNumberOfBranches,1);
            this.mBranchArea = zeros(this.iNumberOfBranches,1);
            this.mInverseBranchLength = zeros(this.iNumberOfBranches,1);

            this.cDeltaPressureComp = cell(this.iNumberOfBranches,1);
            this.cDeltaTempComp = cell(this.iNumberOfBranches,1);
            this.cPressureLossComp = cell(this.iNumberOfBranches,1);
            
            for k = 1:this.iNumberOfBranches

                %the meta values are used to decide whether a component even
                %has the respective attribute because not necessarily all
                %components have alle the attributes
                mDeltaPressure = zeros(this.iNumberOfProcs(k),1);
                mDirectionDeltaPressureComp = zeros(this.iNumberOfProcs(k),1);
                mDeltaTemp = zeros(this.iNumberOfProcs(k),1);
                mHydrDiamComp = zeros(this.iNumberOfProcs(k),1);
                mHydrLengthComp = zeros(this.iNumberOfProcs(k),1);
                mHydrDiamValve = -1*ones(this.iNumberOfProcs(k),1);

                for m = 1:this.iNumberOfProcs(k)
                    %if the processor with index k has the respective property
                    %its value is written into the respective vector. If not
                    %the vector entry remains zero or for the diameter -1.
                    if isprop(this.oSystem.aoBranches(k).aoFlowProcs(1,m), 'fDeltaPressure') && ~isempty(this.oSystem.aoBranches(k).aoFlowProcs(1,m).fDeltaPressure)
                        mDeltaPressure(m) = [ this.oSystem.aoBranches(k).aoFlowProcs(1,m).fDeltaPressure ];
                    end
                    if isprop(this.oSystem.aoBranches(k).aoFlowProcs(1,m), 'fDeltaTemp') && ~isempty(this.oSystem.aoBranches(k).aoFlowProcs(1,m).fDeltaTemp)
                        mDeltaTemp(m) = [ this.oSystem.aoBranches(k).aoFlowProcs(1,m).fDeltaTemp ];
                    end
                    if isprop(this.oSystem.aoBranches(k).aoFlowProcs(1,m), 'iDir') && ~isempty(this.oSystem.aoBranches(k).aoFlowProcs(1,m).iDir)
                        mDirectionDeltaPressureComp(m) = [ this.oSystem.aoBranches(k).aoFlowProcs(1,m).iDir ];
                    end
                    if isprop(this.oSystem.aoBranches(k).aoFlowProcs(1,m), 'fHydrDiam') && ~isempty(this.oSystem.aoBranches(k).aoFlowProcs(1,m).fHydrDiam)
                        mHydrDiamComp(m) = [ this.oSystem.aoBranches(k).aoFlowProcs(1,m).fHydrDiam ];
                    elseif isprop(this.oSystem.aoBranches(k).aoFlowProcs(1,m), 'fDiameter') && ~isempty(this.oSystem.aoBranches(k).aoFlowProcs(1,m).fDiameter)
                        mHydrDiamComp(m) =  [ this.oSystem.aoBranches(k).aoFlowProcs(1,m).fDiameter ];
                    end
                    if isprop(this.oSystem.aoBranches(k).aoFlowProcs(1,m), 'fHydrLength') && ~isempty(this.oSystem.aoBranches(k).aoFlowProcs(1,m).fHydrLength)
                        mHydrLengthComp(m) = [ this.oSystem.aoBranches(k).aoFlowProcs(1,m).fHydrLength ];
                    elseif isprop(this.oSystem.aoBranches(k).aoFlowProcs(1,m), 'fLength') && ~isempty(this.oSystem.aoBranches(k).aoFlowProcs(1,m).fLength)
                        mHydrLengthComp(m) = [ this.oSystem.aoBranches(k).aoFlowProcs(1,m).fLength ]; 
                    end
                    if isprop(this.oSystem.aoBranches(k).aoFlowProcs(1,m), 'fHydrDiam') && ~isempty(this.oSystem.aoBranches(k).aoFlowProcs(1,m).fHydrDiam) && mHydrLengthComp(m) == 0
                        mHydrDiamValve(m) = [ this.oSystem.aoBranches(k).aoFlowProcs(1,m).fHydrDiam ];
                    elseif isprop(this.oSystem.aoBranches(k).aoFlowProcs(1,m), 'fDiameter') && ~isempty(this.oSystem.aoBranches(k).aoFlowProcs(1,m).fDiameter) && mHydrLengthComp(m) == 0
                        mHydrDiamValve(m) = [ this.oSystem.aoBranches(k).aoFlowProcs(1,m).fDiameter ];
                    else
                        %this is necessary in order to discern between procs
                        %that simply dont have a diameter definition and one
                        %that actually have a diameter of 0 like closed valves.
                        mHydrDiamValve(m) = -1;
                    end
                end

                %these values are used by the individual branches to
                %calculate the flow temperatures and pressures
                this.cDeltaPressureComp{k} = mDirectionDeltaPressureComp.*mDeltaPressure;
                this.cDeltaTempComp{k} = mDeltaTemp;
                mHelper = zeros(this.iNumberOfProcs(k),1);
                mHelper(mDirectionDeltaPressureComp == 0) = mDeltaPressure(mDirectionDeltaPressureComp == 0);
                this.cPressureLossComp{k} = mHelper;

                %Each entry of mDeltaPressureCompsTotal contains the sum of the pressure 
                %difference from components with a specified direction (pumps)
                %for the respective branch
                this.mDeltaPressureCompsTotal(k) = sum(mDirectionDeltaPressureComp.*mDeltaPressure);
                this.mDeltaTempCompsTotal(k) = sum(mDeltaTemp);
                %Each entry of the mPressureLoss vector contains the sum of all
                %the pressure losses in the respective branch
                this.mPressureLoss(k) = sum(mDeltaPressure(mDirectionDeltaPressureComp == 0));

                mMinHydrDiamBranch = mHydrDiamComp(mHydrDiamComp ~= -1);
                mMinHydrDiamBranch = min(mMinHydrDiamBranch(mMinHydrDiamBranch ~= 0));
                if ~isempty(min(mHydrDiamValve(mHydrDiamValve ~= -1)))
                    mMinHydrDiamBranch = min(mMinHydrDiamBranch, min(mHydrDiamValve(mHydrDiamValve ~= -1)));
                end

                this.mMinHydrDiam(k) = mMinHydrDiamBranch;
                this.mBranchArea(k) = this.mMinHydrDiam(k)^2*pi*0.25;
                this.mInverseBranchLength(k) = 1/(sum(mHydrLengthComp(mHydrLengthComp > 0)));
                this.mBranchLength(k) = (sum(mHydrLengthComp(mHydrLengthComp > 0)));
            end
            
            this.mPhasePressures = zeros(this.iNumberOfBranches,2);
            for k = 1:this.iNumberOfBranches
                this.mPhasePressures(k,1) = this.oSystem.aoBranches(k,1).coExmes{1,1}.oPhase.fPressure;
                this.mPhasePressures(k,2) = this.oSystem.aoBranches(k,1).coExmes{2,1}.oPhase.fPressure;
            end
            
            %checks if steady state can still be applied
            if this.bSteadyState == 1
                if (max(abs(this.mPhasePressuresOld(:,1) - this.mPhasePressures(:,1))) > 10) ||...
                   (max(abs(this.mPhasePressuresOld(:,2) - this.mPhasePressures(:,2))) > 10) ||...
                   (max(abs(this.mDeltaPressureCompsTotalOld - this.mDeltaPressureCompsTotal)) > 10) ||...
                   (max(abs(this.mPressureLossOld - this.mPressureLoss)) > 10) ||...
                   (max(abs(this.mDeltaTempCompsTotalOld - this.mDeltaTempCompsTotal)) > 0.1) ||...
                   (max(abs(this.mMinHydrDiamOld - this.mMinHydrDiam)) > 1e-4)
               
                    this.bSteadyState = 0;
                    this.iSteadyStateCounter = -10;
                    this.fTimeStepSystem = this.fMinTimeStep;
                end
               
            end
            
            if this.bSteadyState == 0
                %Vector containing the pressure of the stores
                mPhaseDensities = zeros(this.iNumberOfBranches,2);
                mPhaseMass = zeros(this.iNumberOfBranches,2);
                mDynamicViscosity = zeros(this.iNumberOfBranches,2);
                for k = 1:this.iNumberOfBranches

                    mPhaseDensities(k,1) = this.oSystem.aoBranches(k,1).coExmes{1,1}.oPhase.fDensity;
                    mPhaseDensities(k,2) = this.oSystem.aoBranches(k,1).coExmes{2,1}.oPhase.fDensity;

                    mPhaseMass(k,1) = this.oSystem.aoBranches(k,1).coExmes{1,1}.oPhase.fMass;
                    mPhaseMass(k,2) = this.oSystem.aoBranches(k,1).coExmes{2,1}.oPhase.fMass;

                    mDynamicViscosity(k,1) = this.oSystem.oData.oMT.calculateDynamicViscosity(this.oSystem.aoBranches(k,1).coExmes{1,1}.oPhase);
                    mDynamicViscosity(k,2) = this.oSystem.oData.oMT.calculateDynamicViscosity(this.oSystem.aoBranches(k,1).coExmes{2,1}.oPhase);
                end

                %% Calculates the acceleration inside the branches
                
                %first the delta pressure over the branches is calculated
                %(the pressure always has to lower the absolute value of
                %the pressure difference)
                mDeltaPressureBranches = ((this.mPhasePressures(:,1)-this.mPhasePressures(:,2))+this.mDeltaPressureCompsTotal);
                
                %The pressure loss has to act against the current flow
                %direction. Therefore the sign of the old flow speed is
                %multiplied with the (always positive) pressure loss and
                %the result is subtracted from the delta pressure in the
                %branches. Therefore for a negative flow speed the pressure
                %loss acts as a positive pressure and vice versa.
                mDeltaPressureBranchesWithLoss = mDeltaPressureBranches - (sign(this.mFlowSpeedOld).*this.mPressureLoss);
                
                mAccelerationNew = (mDeltaPressureBranchesWithLoss.*this.mInverseBranchLength);

                %it saves time to use the originating store densities
                %instead of the matter table to calculate the densities.
                this.mBranchDensities = zeros(this.iNumberOfBranches,1);
                this.mBranchDensities(this.mFlowSpeedOld >= 0) = mPhaseDensities((this.mFlowSpeedOld >= 0),1);
                this.mBranchDensities(this.mFlowSpeedOld < 0) = mPhaseDensities((this.mFlowSpeedOld < 0),2);

                mAccelerationNew = mAccelerationNew./ this.mBranchDensities;
                
                %% Time Step calculation 
                %the assumed ranged in which the flow speed is allowed to
                %move
                mFlowSpeedHigh = abs(this.mFlowSpeedOld).*(1+this.fMaxProcentualFlowSpeedChange);

                %if the old flow rate is 0 the assumption is that new
                %highest flow speed is 1 m/s. Also the minimum allowed
                %absolute flow speed change is 1 m/s
                mFlowSpeedHigh(mFlowSpeedHigh <= 1) = mFlowSpeedHigh(mFlowSpeedHigh <= 1) + 1;

                mStep = zeros(length(this.mFlowSpeedOld(this.mBranchArea ~= 0)),1);
                mStep(:,1) = abs((mFlowSpeedHigh(this.mBranchArea ~= 0) - abs(this.mFlowSpeedOld(this.mBranchArea ~= 0)))./mAccelerationNew(this.mBranchArea ~= 0));
                
                fTimeStepOld = this.fTimeStepSystem;
                %gets the smallest positiv non NaN step
                this.fTimeStepSystem = min(mStep(mStep > 0));
                if this.fTimeStepSystem > 1.1*fTimeStepOld
                    this.fTimeStepSystem = 1.1*fTimeStepOld;
                end
                %in case the time step is outside of the user specified
                %boundaries it gets reset to the boundary
                if this.fTimeStepSystem > this.fMaxTimeStep
                    this.fTimeStepSystem = this.fMaxTimeStep;
                elseif this.fTimeStepSystem < this.fMinTimeStep
                    this.fTimeStepSystem = this.fMinTimeStep;
                end

                %if the valves close the solver assumes that no massflow went
                %through it in the previous time step
                for k = 1:this.iNumberOfBranches
                    if this.mBranchArea(k) == 0
                        this.mMassFlowOld(k,end) = 0;
                    end
                end
                

                %% calculates the new mass flow
                mMassFlowNew = (mDeltaPressureBranchesWithLoss.*this.mInverseBranchLength)...
                            .*this.mBranchArea*(this.fTimeStepSystem/this.iPartSteps)+this.mMassFlowOld(:,end);
                   
                %The pressure loss is not allowed to act as a driving
                %force, which means that if the flow speed is small the
                %maximum flow speed change the pressure loss is allowed to
                %creat is setting the flowrate down to zero!
                %TO DO: this needs a bit more work to ensure that the
                %pressure loss is just not acting as driving force
                bDirectionChange = (sign(this.mMassFlowOld(:,end)) ~= sign(mMassFlowNew));
                if max(bDirectionChange) == 1
                    bPressureLossDriving = (sign(mDeltaPressureBranches) ~= sign(mDeltaPressureBranchesWithLoss));
                    bSetFlowToZero = bPressureLossDriving+ bDirectionChange;
                    bSetFlowToZero = bSetFlowToZero == 2;
                    mMassFlowNew(bSetFlowToZero) = 0;
                end
                
                %% unidirectional restricor valve calculation
                %in case a restrictor valve is inside the branch and the
                %mass flow would go against this valve the massflow and the 
                %branch area is set to zero and the valve is closed. The
                %opening of the valve is done in the valves update function
                %this query here is only necessary because otherwise if the
                %mass flow goes against the valve direction it takes the
                %valve one timestep to realize it and some matter can go
                %against it.
                for k = 1:this.iNumberOfBranches
                    if max(abs(this.cRestrictorValve{k})) == 1
                        if sign(mMassFlowNew(k)) ~= this.cRestrictorValve{k}(this.cRestrictorValve{k}~=0)
                            this.mBranchArea(k) = 0;
                            mMassFlowNew(k) = 0;
                            this.oSystem.aoBranches(k,1).aoFlowProcs(1,this.cRestrictorValve{k}~=0).setValvePos(0)
                        end
                    end
                end
                
                %gets the flow rates from all p2p procs in the boundary
                %phases in order to consider their influence when
                %calculating the predicor corrector calculation
                for m = 1:length(this.cPhaseNames)
                    %TO DO: This allocation has to be fixed in case the
                    %store contains P2P procs that are not connected to the
                    %phase that is adjacent to any of the solver branches.
                    csProcsP2P = this.oSystem.toStores.(this.tStoreNames.(this.cPhaseNames{m})).csProcsP2P;
                    tP2PFlowRate.(this.cPhaseNames{m}) = 0;
                    for n = 1:length(csProcsP2P)
                        fFlowRateP2P = this.oSystem.toStores.(this.tStoreNames.(this.cPhaseNames{m})).toProcsP2P.(csProcsP2P{n}).fFlowRate;
                        sInName = this.oSystem.toStores.(this.tStoreNames.(this.cPhaseNames{m})).toProcsP2P.(csProcsP2P{n}).oIn.oPhase.sName;
                        %the phase oIn for the P2P proc means in with
                        %regard to the P2P procs, so for the phase if
                        %it is labeled as In phase for the proc a
                        %positive flow rate goes out with respect to
                        %the phase
                        if strcmp(sInName,  this.cPhaseNames{m})
                            tP2PFlowRate.(this.cPhaseNames{m}) = tP2PFlowRate.(this.cPhaseNames{m}) - fFlowRateP2P;
                        else
                            tP2PFlowRate.(this.cPhaseNames{m}) = tP2PFlowRate.(this.cPhaseNames{m}) + fFlowRateP2P;
                        end
                    end
                end
                %% predictor corrector calculation
                %calculates the predicted new store masses and from those
                %the new pressures. Also predicts the pressure loss in the
                %branches. Then uses those predicted values to predict the
                %acceleration that would act on the branches if the current
                %calculated mass flow was used and then averages the
                %calculation used above and the predicted acceleration to
                %get a new value for the acceleration and calculate a new
                %mass flow. Then the process is repeated until the mass
                %flow has converged or the maximum number of steps has been
                %reached.
                
                mNewStoreMass = zeros(this.iNumberOfBranches,2);
                %calculates the new store masses using the current mass
                %flow calculated for this time step
                mAccelerationPredictor = zeros(this.iNumberOfBranches, this.iPartSteps);
                mMassFlowStep = zeros(this.iNumberOfBranches, this.iPartSteps);
                mTimePerStep = zeros(1, this.iPartSteps);
                mTimePerStep(1,1) = this.fTimeStepSystem/this.iPartSteps;
                mMassFlowStep(:,1) = mMassFlowNew;
                mFlowSpeedStep = zeros(this.iNumberOfBranches, this.iPartSteps);
                %TO DO: Improve this part steps calculation to become
                %more efficient. There are quite a few steps within
                %this that do not have to be executed for each part
                %step
                for Step = 1:this.iPartSteps
                    for m = 1:length(this.cPhaseNames)
                        mNewStoreMass(this.sConectivityMatrix.(this.cPhaseNames{m})) = mPhaseMass(this.sConectivityMatrix.(this.cPhaseNames{m}))...
                            + (sum(this.sConectivityMatrix.(this.cPhaseNames{m})(:,2) .* (mMassFlowStep(:,1:Step)*mTimePerStep(1:Step)') + ...
                            this.sConectivityMatrix.(this.cPhaseNames{m})(:,1) .* -(mMassFlowStep(:,1:Step)*mTimePerStep(1:Step)')));

                        mNewStoreMass(this.sConectivityMatrix.(this.cPhaseNames{m})) = mNewStoreMass(this.sConectivityMatrix.(this.cPhaseNames{m}))+...
                            (tP2PFlowRate.(this.cPhaseNames{m})*sum(mTimePerStep(1:Step)));
                    end 

                    %the pressure change in the stores is assumed to be
                    %proportional to the mass change in the stores
                    mPressureChangeRatio(:,1) = mNewStoreMass(:,1)./mPhaseMass(:,1);
                    mPressureChangeRatio(:,2) = mNewStoreMass(:,2)./mPhaseMass(:,2);

                    %calculates the new store densities and from those the
                    %new branch densities
                    mNewStoreDensities = mPhaseDensities.*mPressureChangeRatio;
                    mNewBranchDensities = zeros(this.iNumberOfBranches,1);
                    mNewBranchDensities(this.mFlowSpeedOld >= 0) = mNewStoreDensities((this.mFlowSpeedOld >= 0),1);
                    mNewBranchDensities(this.mFlowSpeedOld < 0) = mNewStoreDensities((this.mFlowSpeedOld < 0),2);

                    %calculates the current and the new flow speed in the
                    %branches
                    mFlowSpeed = this.mMassFlowOld(:,end) ./ (this.mBranchDensities.*this.mBranchArea);
                    mFlowSpeedStep(:,Step) = mMassFlowStep(:,Step) ./ (mNewBranchDensities.*this.mBranchArea);

                    mBranchViscosities = zeros(this.iNumberOfBranches,1);
                    mBranchViscosities(this.mFlowSpeedOld >= 0) = mDynamicViscosity((this.mFlowSpeedOld >= 0),1);
                    mBranchViscosities(this.mFlowSpeedOld < 0) = mDynamicViscosity((this.mFlowSpeedOld < 0),2);

                    %predicts the pressure loss by assuming that the
                    %branches are simple pipes and calculating the pressure
                    %loss for that assumption with the old and the new
                    %values. Then a pressure loss change factor is
                    %calculated by dividing those values with each other.
                    %The predicted pressure loss is then calculated by
                    %multiplying this factor with the current pressure loss
                    %in the branches.
                    mPressureLossNew = zeros(this.iNumberOfBranches,1);
                    mPressureLossPipeOld = zeros(this.iNumberOfBranches,1);
                    mPressureLossPredictor = zeros(this.iNumberOfBranches,1);
                    for k = 1:this.iNumberOfBranches
                        try 
                            for n = 1:length(this.oSystem.aoBranches(k).aoFlowProcs)
                                mPressureLossPredictor(k) = mPressureLossPredictor(k)+this.oSystem.aoBranches(k).aoFlowProcs(n).solverDeltas(mMassFlowStep(k,Step), mNewBranchDensities(k), mBranchViscosities(k));
                            end
                        catch
                            mPressureLossNew(k) = pressure_loss_pipe(sqrt(this.mBranchArea(k)/(0.25*pi)), 1/this.mInverseBranchLength(k),...
                                        mFlowSpeedStep(k,Step), mBranchViscosities(k), mNewBranchDensities(k), 0.0002, 0);
                            mPressureLossPipeOld(k) = pressure_loss_pipe(sqrt(this.mBranchArea(k)/(0.25*pi)), 1/this.mInverseBranchLength(k),...
                                        mFlowSpeed(k), mBranchViscosities(k), mNewBranchDensities(k), 0.0002, 0);
                            if mPressureLossPipeOld < 1e-3 
                                %if the old pressure loss is close to zero the
                                %calculation for the pressure loss predictor would
                                %contain something that comes close to a division
                                %through 0, therefore in this case the predicted
                                %pressure is assumed to be the acutal old pressure
                                %loss
                                mPressureLossPredictor(k) = this.mPressureLoss(k);
                            else
                                mPressureLossPredictor(k) = (this.mPressureLoss(k)*(mPressureLossNew(k)/mPressureLossPipeOld(k)));
                            end
                        end
                    end
                    mPressureLossPredictor(isnan(mPressureLossPredictor)) = 0;
                    mPressureLossPredictor(isinf(mPressureLossPredictor)) = 0;


                    mPhasePressuresPredictor = (this.mPhasePressures.*mPressureChangeRatio);


                    %calculates the PREDICTED delta pressure over the
                    %branches
                    mDeltaPressureBranchesPredictor = ((mPhasePressuresPredictor(:,1)-mPhasePressuresPredictor(:,2))+this.mDeltaPressureCompsTotal);


                    %The pressure loss has to act against the current flow
                    %direction. Therefore the sign of the old flow speed is
                    %multiplied with the (always positive) pressure loss and
                    %the result is subtracted from the delta pressure in the
                    %branches. Therefore for a negative flow speed the pressure
                    %loss acts as a positive pressure and vice versa.
                    mDeltaPressureBranchesWithLoss = mDeltaPressureBranches - (sign(this.mFlowSpeedOld).*this.mPressureLoss);
                    mDeltaPressureBranchesWithLossPredictor = mDeltaPressureBranchesPredictor - (sign(mFlowSpeedStep(:,Step)).*mPressureLossPredictor);

                    %acceleration that is predicted to act on the branches
                    %at the time t+delta t
                    mAccelerationPredictor(:,Step) = (mDeltaPressureBranchesWithLossPredictor.*this.mInverseBranchLength) ./ mNewBranchDensities;

                    % Time Step calculation 
                    %the assumed ranged in which the flow speed is allowed to
                    %move
                    mFlowSpeedHigh = abs(mFlowSpeedStep(:,Step)).*(1+(this.fMaxProcentualFlowSpeedChange/this.iPartSteps));

                    %if the old flow rate is 0 the assumption is that new
                    %highest flow speed is 1 m/s. Also the minimum allowed
                    %absolute flow speed change is 1 m/s
                    mFlowSpeedHigh(mFlowSpeedHigh <= 1) = mFlowSpeedHigh(mFlowSpeedHigh <= 1) + 1;

                    mStep = zeros(length(this.mFlowSpeedOld(this.mBranchArea ~= 0)),1);
                    if Step == 1
                        mStep(:,1) = abs((mFlowSpeedHigh(this.mBranchArea ~= 0) - abs(this.mFlowSpeedOld(this.mBranchArea ~= 0)))./mAccelerationPredictor((this.mBranchArea ~= 0),Step));
                    else
                        mStep(:,1) = abs((mFlowSpeedHigh(this.mBranchArea ~= 0) - abs(mFlowSpeedStep((this.mBranchArea ~= 0),Step-1)))./mAccelerationPredictor((this.mBranchArea ~= 0),Step));
                    end
                    %gets the smallest positiv non NaN step
                    try
                        mTimePerStep(Step+1) = min(mStep(mStep > 0));
                        if mTimePerStep(Step+1) > 2*mTimePerStep(Step)
                            mTimePerStep(Step+1) = 2*mTimePerStep(Step);
                        end
                        if mTimePerStep(Step+1) > this.fMaxTimeStep/this.iPartSteps
                            mTimePerStep(Step+1) = this.fMaxTimeStep/this.iPartSteps;
                        elseif mTimePerStep(Step+1) < this.fMinTimeStep/this.iPartSteps
                            mTimePerStep(Step+1) = this.fMinTimeStep/this.iPartSteps;
                        end
                    catch
                        %if all steps are zero, it sets the minimum step
                        mTimePerStep(Step+1) = this.fMinTimeStep/this.iPartSteps;
                    end

                    mMassFlowStep(:,Step+1) = mAccelerationPredictor(:,Step).*mNewBranchDensities.*this.mBranchArea.*(mTimePerStep(Step))+mMassFlowStep(:,(Step));

                    bDirectionChange = (sign(this.mMassFlowOld(:,end)) ~= sign(mMassFlowStep(:,Step+1)));
                    if max(bDirectionChange) == 1
                        bPressureLossDriving = (sign(mDeltaPressureBranchesPredictor) ~= sign(mDeltaPressureBranchesWithLossPredictor));
                        bSetFlowToZero = bPressureLossDriving+ bDirectionChange;
                        bSetFlowToZero = bSetFlowToZero == 2;
                        mMassFlowStep(bSetFlowToZero,Step+1) = 0;
                    end

                end

                mMassFlowSum = zeros(this.iNumberOfBranches, 1);
                mAccelerationSum = zeros(this.iNumberOfBranches, 1);
                for Step = 1:this.iPartSteps
                    mMassFlowSum = mMassFlowSum + (mMassFlowStep(:,Step).*mTimePerStep(Step));
                    mAccelerationSum = mAccelerationSum+(mAccelerationPredictor(:,Step).*mTimePerStep(Step));
                end
                mMassFlowSum = mMassFlowSum + (mMassFlowStep(:,this.iPartSteps+1).*mTimePerStep(this.iPartSteps+1));

                mMassFlowNew = ((mMassFlowSum)./sum(mTimePerStep));
                mAcceleration = ((mAccelerationSum)./sum(mTimePerStep(1:this.iPartSteps)));

                %The pressure loss is not allowed to act as a driving
                %force, which means that if the flow speed is small the
                %maximum flow speed change the pressure loss is allowed to
                %creat is setting the flowrate down to zero!
                %TO DO: this needs a bit more work to ensure that the
                %pressure loss is just not acting as driving force
                bDirectionChange = (sign(this.mMassFlowOld(:,end)) ~= sign(mMassFlowNew));
                if max(bDirectionChange) == 1
                    bPressureLossDriving = (sign(mDeltaPressureBranches) ~= sign(mDeltaPressureBranchesWithLoss));
                    bSetFlowToZero = bPressureLossDriving+ bDirectionChange;
                    bSetFlowToZero = bSetFlowToZero == 2;
                    mMassFlowNew(bSetFlowToZero) = 0;
                end

                this.fTimeStepSystem = sum(mTimePerStep);

                %in case the time step is outside of the user specified
                %boundaries it gets reset to the boundary
                if this.fTimeStepSystem > this.fMaxTimeStep
                    this.fTimeStepSystem = this.fMaxTimeStep;
                elseif this.fTimeStepSystem < this.fMinTimeStep
                    this.fTimeStepSystem = this.fMinTimeStep;
                end

                
                %TO DO: Delete once finished, this is debugging check used
                %during development
                if (max(isnan(mMassFlowNew)) == 1) || (max(isinf(mMassFlowNew)) == 1) || (max(abs(mMassFlowNew)) > 100)
                    keyboard()
                end

                %% steady state check
                % Steady state is assumed to be reached once the
                % acceleration in all the branches is small
                if max(abs(mAcceleration(this.mBranchArea ~= 0))) < 10
                    this.iSteadyStateCounter = this.iSteadyStateCounter+1;
                else
                    this.iSteadyStateCounter = 0;
                end
                %set the values for which the system was last calculated
                %into the respective properties. This is then used to see
                %if some event e.g. turned on a pump and therefore requires
                %the system to be recalculated. (also if a valve is
                %closed/opened etc, basically if anything changes too much 
                %the system is recalculated)
                if this.iSteadyStateCounter == 10
                    this.bSteadyState = true;
                    
                    this.mPhasePressuresOld = this.mPhasePressures;
                    this.mDeltaPressureCompsTotalOld = this.mDeltaPressureCompsTotal;
                    this.mPressureLossOld = this.mPressureLoss;
                    this.mDeltaTempCompsTotalOld = this.mDeltaTempCompsTotal;
                    this.mMinHydrDiamOld = this.mMinHydrDiam;
                    
                end
                
                %updates the flowprocs
                for k = 1:this.iNumberOfBranches
                    for m = 1:this.iNumberOfProcs(k)
                        try
                            this.oSystem.aoBranches(k).aoFlowProcs(1,m).update();
                        catch
                            %if it cannot be update it cannot be updated
                        end
                    end
                end
                
            %% steady state
            else
                this.fTimeStepSystem  = this.fSteadyStateTimeStep;
                
                %gets the flow rates from all p2p procs in the boundary
                %phases in order to consider their influence when
                %calculating the predicor corrector calculation
                for m = 1:length(this.cPhaseNames)
                    %TO DO: This allocation has to be fixed in case the
                    %store contains P2P procs that are not connected to the
                    %phase that is adjacent to any of the solver branches.
                    csProcsP2P = this.oSystem.toStores.(this.tStoreNames.(this.cPhaseNames{m})).csProcsP2P;
                    tP2PFlowRate.(this.cPhaseNames{m}) = 0;
                    for n = 1:length(csProcsP2P)
                        fFlowRateP2P = this.oSystem.toStores.(this.tStoreNames.(this.cPhaseNames{m})).toProcsP2P.(csProcsP2P{n}).fFlowRate;
                        sInName = this.oSystem.toStores.(this.tStoreNames.(this.cPhaseNames{m})).toProcsP2P.(csProcsP2P{n}).oIn.oPhase.sName;
                        %the phase oIn for the P2P proc means in with
                        %regard to the P2P procs, so for the phase if
                        %it is labeled as In phase for the proc a
                        %positive flow rate goes out with respect to
                        %the phase
                        if strcmp(sInName,  this.cPhaseNames{m})
                            tP2PFlowRate.(this.cPhaseNames{m}) = tP2PFlowRate.(this.cPhaseNames{m}) - fFlowRateP2P;
                        else
                            tP2PFlowRate.(this.cPhaseNames{m}) = tP2PFlowRate.(this.cPhaseNames{m}) + fFlowRateP2P;
                        end
                    end
                end
                
                %Now the number of in an out flows for each store are
                %calculated
                for m = 1:length(this.cPhaseNames)
                    tNumberOfInFlows.(this.cPhaseNames{m,1}) = length(find(this.sConectivityMatrix.(this.cPhaseNames{m})(:,2)));
                    tNumberOfOutFlows.(this.cPhaseNames{m,1}) = length(find(this.sConectivityMatrix.(this.cPhaseNames{m})(:,1)));
                    %if anything is empty this means that this store does not
                    %have any in or out flows.
                    if isempty(tNumberOfInFlows.(this.cPhaseNames{m,1}))
                        tNumberOfInFlows.(this.cPhaseNames{m,1}) = 0;
                    end
                    if isempty(tNumberOfOutFlows.(this.cPhaseNames{m,1}))
                        tNumberOfOutFlows.(this.cPhaseNames{m,1}) = 0;
                    end
                end
                
                %Now you'll have to bear with a bit of theory to explain
                %how the following calculations work:
                
                %With this knowledge it is possible to differentiate
                %between four basic possible configurations for each phase:
                % A1. the phase has as many in- as outflows       (e.g. the phase passes a mass flow on to another phase)
                % A2. the phase has more in- than outflows        (e.g. the phase combines multiple mass flows)
                % A3. the phase has more out- than inflows        (e.g. the phase splits a mass flow)
                % A4. the phase has either no in- or no outflow   (e.g. two phases equalizing their pressure)
                
                % Depending on which configuration the phase is in the
                % steady state calculation has to differ. 
                
                % Furthermore it is possible that mutliple phases are interdependant over
                % several branches while not beeing connected directly with
                % a branch. 
                % For this system wide perspective there exist two different 
                % types of connections between phases.
                %
                % B1: Loop 1 --> 2 --> 3 --> 4 --> 1
                % the connection between the phases results in a loop
                % where fluid can flow in a circle therefore allowing
                % constant flow rates in steady state
                %
                % B2: Line 1 --> 2 --> 3 --> 4
                % the connections result in a line with a phase that only
                % has an outflow on the one end and a phase that only has
                % an inflow in the other. Therefore the only possible
                % steady state solution for this system is a flow rate of
                % zero in all branches.
                
                % Since the flow rate for the line branches is already
                % known to be zero in steady state this flow rate is set
                % here for all branches. The branches that do not have a
                % zero flow rate are specified by the user input
                % mLoopBranches and for those the zero flow rate will be
                % overwriten.
                mMassFlowNew = zeros(this.iNumberOfBranches,1);
                mAcceleration = zeros(this.iNumberOfBranches,1);
                
                %TO DO: Finish this...
                %For the loop configuration the highest mass flow within
                %each loop is selected and the loop calculation for each
                %loop starts from the phase into which this mass flow is
                %flowing.
                iNumberOfLoops = size(this.mLoopBranches);
                iNumberOfLoops = iNumberOfLoops(2);
                mMaxLoopFlow = zeros(iNumberOfLoops,1);
                cLoopFlowRates = cell(iNumberOfLoops,1);
                for l = 1:iNumberOfLoops
                    %TO DO: Get this to work for negative flow rates, and
                    %for the case if the loop has no single branch through
                    %which the whole loop flow rate has to pass
                    mMaxLoopFlow(l) = max(this.mMassFlowOld(this.mLoopBranches(:,l),end));
                    cLoopFlowRates{l} = this.mMassFlowOld(this.mLoopBranches(:,l),end);
                    Helper = find(cLoopFlowRates{l} == mMaxLoopFlow(l));
                    %Index of the branch with the highest flow rate for
                    %each loop with regard to the cLoopFlowRates Indices
                    %for each loop
                    iMaxLoopFlowBranch = Helper(1);
                    
                    iOverallIndexMax = this.mLoopBranches(iMaxLoopFlowBranch,l);
                    %The maximum loop flow can now be set as first value
                    %into the mMassFlowNew variable as starting point for
                    %this loop
                    mMassFlowNew(iOverallIndexMax) = mMaxLoopFlow(l);
                    
                    iCounterForLoop = 0;
                    %TO DO: Find a better solution than a while loop and
                    %make it work for negative flow rates as well
                    if mMaxLoopFlow(l) >= 0
                        %until all flowrates within the loop are unequal to
                        %zero the calculation is redone
                        while (max(mMassFlowNew(this.mLoopBranches(:,l))==0) == 1)
                            for m = 1:length(cLoopFlowRates{l})
                                [LeftPhase, ~] = this.cPhaseNameMatrix{this.mLoopBranches(m,l),:};

                                %Vector that contains 1 for each branch that comes
                                %after this one in the overall notation
                                bmFollowingBranches = this.sConectivityMatrix.(LeftPhase)(:,1);
                                %Vector that contains the indices of the
                                %following branches
                                miIndexFollowingBranches = find(bmFollowingBranches);

                                %Vector that contains 1 for each branch that comes
                                %before this one in the overall notation
                                bmPreviousBranches = this.sConectivityMatrix.(LeftPhase)(:,2);
                                %Vector that contains the indices of the
                                %branches before this one
                                miIndexPreviousBranches = find(bmPreviousBranches);
                                
                                if length(miIndexFollowingBranches) > 1
                                    %For more than one followup branches a split
                                    %ratio between these followup branches based on
                                    %their current flowrates has to be calculated
                                    for k = 1:length(miIndexFollowingBranches)
                                        fSplitRatio = this.mMassFlowOld(miIndexFollowingBranches(k),end)/sum(this.mMassFlowOld(miIndexFollowingBranches,end));

                                        %In order to set the new mass flow
                                        %for the follow up branches the
                                        %inlet mass flows to the phase have
                                        %to be known. If that is not the
                                        %case they are not set
                                        if max(mMassFlowNew(miIndexPreviousBranches) == 0) == 0
                                            mMassFlowNew(miIndexFollowingBranches(k)) = sum(mMassFlowNew(miIndexPreviousBranches))*fSplitRatio;
                                        end
                                    end
                                else
                                    %In order to set the new mass flow
                                    %for the follow up branches the
                                    %inlet mass flows to the phase have
                                    %to be known. If that is not the
                                    %case they are not set
                                    if max(mMassFlowNew(miIndexPreviousBranches) == 0) == 0
                                        mMassFlowNew(miIndexFollowingBranches) = sum(mMassFlowNew(miIndexPreviousBranches));
                                    end
                                end
                            end
                            iCounterForLoop = iCounterForLoop + 1;
                            if iCounterForLoop == 100
                                keyboard()
                            end
                        end
                    end
                end
                
                
                
                
                % TO DO: Write a calculation that automatically decides how
                % the branches are connected thus no longer requiring the
                % user to input mLoopBranches
                
                %The difficullty now is to discern between these different
                %cases. First the phases that are definit end points are
                %discerned by searching for all phases that only have
                %either in- or outflows (which means that either in- or
                %outflows are 0 for this phase making it a one way trip for
                %mass)
                
%                 for m = 1:length(this.cPhaseNames)
%                     if tNumberOfInFlows.(this.cPhaseNames{m,1}) == 0
%                         this.cLineStartStores{end+1,1} = this.cPhaseNames{m,1};
%                     end
%                     if tNumberOfOutFlows.(this.cPhaseNames{m,1}) == 0
%                         this.cLineEndStores{end+1,1} = this.cPhaseNames{m,1};
%                     end
%                 end
%                 
%                 % now it has to be decided which phases are in between all
%                 % the start and end phases of each line, the number of
%                 % lines has to be decided and then all the phases in line
%                 % configurations have to be assigned to one line
%                 
%                 this.sConectivityMatrix.(this.cPhaseNames{m})(:,2);
                
                
            end
            
            %% general calculations
            
            this.mMassFlow = mMassFlowNew;
            
            if (max(isnan(this.mMassFlow)) == 1) || (max(isinf(this.mMassFlow)) == 1) || (max(abs(this.mMassFlow)) > 100)
                keyboard()
            end
            
            for k = 2:this.iNumberOfOldSteps
                this.mMassFlowOld(:,k-1) = this.mMassFlowOld(:,k);
                this.mTimeOld(k-1) = this.mTimeOld(k);
            end
            this.mMassFlowOld(:,end) = this.mMassFlow;
            this.mTimeOld(end) = this.oSystem.oTimer.fTime;
            
            this.mFlowSpeedOld = this.mMassFlow./(this.mBranchDensities.*this.mBranchArea);
            
            for k = 2:this.iNumberOfOldSteps
                this.mAccelerationOld(:,k-1) = this.mAccelerationOld(:,k);
            end
            this.mAccelerationOld(:,end) = mAcceleration;

            %the last exec variable is necessary to decide if the solver should
            %be recalculated again. Otherwise it would calculated for each
            %branch in the system calling its update
            this.fLastExec = this.oSystem.oTimer.fTime;
            %next exec is not used by the system solver itself but by the
            %individual branches
            this.fNextExec = this.oSystem.oTimer.fTime+this.fTimeStepSystem;
            
            %if the user defined phases that should be synchronized with
            %the solver time step this time step is set here. Otherwise the
            %normale phase time step calculation is used
            if isprop(this.oSystem, 'aoPhases')
                for k = 1:length(this.oSystem.aoPhases)
                    this.oSystem.aoPhases(k).fFixedTS = this.fTimeStepSystem;
                end
            end
            %writes the object with its new values into the system. Warning
            %here does not really matter.
            this.oSystem.oSystemSolver = this;
        end
        end
    end
end