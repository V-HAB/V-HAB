classdef branch_incompressible_liquid < solver.matter.base.branch
%%Solver branch for incompressible liquids
%
%this is a solver for flows in a branch containing liquids assuming they are
%incompressible
%
%The input arguments are only optional and will be initialzed to specified
%values if nothing is defined by the user
%
%fMaxProcentualMassTransferPerStep: sets the maximum percentage of the 
%   lowest adjacent store mass that can be transfered in one step.
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

    properties (SetAccess = protected, GetAccess = public)
        
        fMassFlow = 0; %kg/s
        
        %these values are not required for the calculation but can be used
        %to plot the respective values.
        fTimeStepBranch = inf;
        
        %Number of the branch in the aoBranches object array
        iBranchNumber = 0;
        iNumberOfProcs = 0;
        
        mDeltaTempComp;
        
    end

    methods 
        %%
        %definition of the branch and the possible input values.
        %For explanation about the values see initial comment section.
        function this = branch_incompressible_liquid(oBranch)
            this@solver.matter.base.branch(oBranch, 0, 'hydraulic');  
            
            if this.iBranchNumber == 0
                for k = 1:length(this.oBranch.oContainer.aoBranches)
                    if strcmp(this.oBranch.sName, this.oBranch.oContainer.aoBranches(k).sName)
                        this.iBranchNumber = k;
                    end
                end
            end
            
            this.iNumberOfProcs = length(this.oBranch.aoFlowProcs);
            
            %with this the branch is considered not updated after its
            %initilaization
            oBranch.setOutdated();
            
        end
    end
    
    methods (Access = protected)
        
        function setFlowRate(this, fMassFlow)
            this.fMassFlow = fMassFlow;
        end
        
        function update(this)
            
            if this.oBranch.oContainer.oSystemSolver.fNextExec <= this.oBranch.oContainer.oTimer.fTime
                this.oBranch.oContainer.oSystemSolver.update();
            end
            
            fTimeStep = this.oBranch.oContainer.oSystemSolver.fTimeStepSystem;
            
            this.setTimeStep(fTimeStep);
            
            %% 
            %get all neccessary variables from the boundaries, procs etc
            %that are stored in the system solver
            
            %gets the values for the Components in the branch
            try
                %this.mDeltaTempComp = this.oBranch.oContainer.oSystemSolver.cDeltaTempComp{this.iBranchNumber};
                mDeltaPressureComp = this.oBranch.oContainer.oSystemSolver.cDeltaPressureComp{this.iBranchNumber}; 
                mPressureLoss = this.oBranch.oContainer.oSystemSolver.cPressureLossComp{this.iBranchNumber}; 
            catch
                return
            end
            %get the properties at the left and right side of the branch.
            %It is important to get the pressure from the exme and not the 
            %store since the liquid exme also tales gravity effects into 
            %account.
            [fPressureBoundary1, ~]  = this.oBranch.coExmes{1}.getPortProperties();
            [fPressureBoundary2, ~]  = this.oBranch.coExmes{2}.getPortProperties();
           
            
            this.fMassFlow = this.oBranch.oContainer.oSystemSolver.mMassFlow(this.iBranchNumber);
            
            %%
            %Calculation of the differences between the flows to
            %generate the values the solver returns to V-HAB.
            %Note that a flow is only located between two different
            %processors (procs) or a proc and a boundary.
            mFlowPressure = zeros(this.iNumberOfProcs+1,1);
            
            if this.fMassFlow >= 0
                mFlowPressure(1) = fPressureBoundary1;
                for k = 2:this.iNumberOfProcs+1
                    mFlowPressure(k) = fPressureBoundary1+sum(mDeltaPressureComp(1:(k-1)))-sum(mPressureLoss(1:(k-1)));
                end
            else
                mFlowPressure(end) = fPressureBoundary2;
                for k = 1:this.iNumberOfProcs
                    mFlowPressure(k) = fPressureBoundary2+sum(mDeltaPressureComp((k+1):end))-sum(mPressureLoss((k+1):end));
                end
            end
            
            afPressure = zeros(this.iNumberOfProcs,1);
            %Positive Deltas for Pressure and Temperature mean a                
            %decrease, negative an increase!
            for k = 1:this.iNumberOfProcs
                afPressure(k) = mFlowPressure(k)-mFlowPressure(k+1);
            end
            
            %%
            %calls the update for the base branch using the newly
            %calculated mass flow
            update@solver.matter.base.branch(this, this.fMassFlow, afPressure);
        end
    end
end