classdef branch < solver.matter.base.branch
    
    properties (SetAccess = protected, GetAccess = public)
        fRequestedFlowRate = 0;
    end
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    properties (SetAccess = private, GetAccess = private, Transient = true)
        
    end
    
    
    methods
        function this = branch(oBranch)
            this@solver.matter.base.branch(oBranch);
        end
        
        
        function this = setFlowRate(this, fFlowRate)
            
            this.fRequestedFlowRate = fFlowRate;
            
            this.registerUpdate();
        end
    end
    
    methods (Access = protected)
        function update(this)
            % We can't set the flow rate directly on this.fFlowRate or on
            % the branch, but have to provide that value to the parent
            % update method.
                        
            % Getting the temperature differences for each processor in the
            % branch
            %
            %TODO still need solution for components to support different 
            %     solvers. Instead of adding fDeltaTemp, other attributes
            %     or methods directly to the f2f class (can't do multiple
            %     inheritance from heterogeneous classes), add an attribute
            %     called toSolvers to the base class. Then each component
            %     can add an instance of a class specifically provided by
            %     the solver itself, or of a subclass of that one, to that
            %     struct, using the solver's name as a key, e.g.
            %     this.toSolvers.manual = solver.matter.manual.f2f(x, y, z)
            %     
            %     Depending on the solver, different parameters can be pro-
            %     vided to the constructor, e.g. a hydraulic diameter and
            %     length etc. In case of the iterative solver, a function
            %     handle might have to be passed to the contructor which
            %     points to a method of the f2f component that can return
            %     the pressure drop and temperature change depending on a
            %     provided flow rate.
            %
            %     The solver then can, on initialization or if a branch 
            %     changes ('rewired' i/f branch), gather the instances to
            %     the solver objects from each f2f procs toSolver attribute
            %     and store them in an array for quick access.
            %
            %     CHECK: if parameters like the hydraulic parameter should
            %            be adjustable during runtime, the solver object
            %            should somehow provide some function handles only
            %            to the f2f 'parent' instead of setting those
            %            parameters to public - same way as it is done in
            %            the branch class?
            %
            if ~isempty(this.oBranch.aoFlowProcs)
                % Need to set press stuff to zeros -> else not set at all!
                %afPress = zeros(1, this.oBranch.iFlowProcs);
                %afTemps = [ this.oBranch.aoFlowProcs.fDeltaTemp ];
                
                
                afTemps = zeros(1, length(this.oBranch.aoFlowProcs));
                for iI=1:length(this.oBranch.aoFlowProcs)
                    afTemps(iI) = this.oBranch.aoFlowProcs(iI).fDeltaTemp;
                end
                
                afPressures = zeros(1, length(this.oBranch.aoFlowProcs));
                for iI=1:length(this.oBranch.aoFlowProcs)
                    afPressures(iI) = this.oBranch.aoFlowProcs(iI).fDeltaPress;
                end
                
                %CHECK - comps do not provide pressure drops so ignore /deactivate
                afPress = zeros(1, this.oBranch.iFlowProcs);
                
                % Can't use this anymore because the array of procs is
                % heterogeneous. Only works if there is just one type of
                % processor in the branch.
                %afTemps = [ this.oBranch.aoFlowProcs.fDeltaTemp ];
                %afPressures = [ this.oBranch.aoFlowProcs.fDeltaPress ];
            else
                %TODO just fix for now ... if [], temps not set :(
                %       --> see flow.setData()
                afPress = 0;
                afTemps = 0; %[];
            end
            
            update@solver.matter.base.branch(this, this.fRequestedFlowRate, afPress, afTemps);
            
            % Checking if there are any active processors in the branch,
            % if yes, update them.
            %TODO see above, solver stuff
            if ~isempty(this.oBranch.aoFlowProcs)
            
                % Checking if there are any active processors in the branch,
                % if yes, update them.
                abActiveProcs = zeros(1, length(this.oBranch.aoFlowProcs));
                for iI=1:length(this.oBranch.aoFlowProcs)
                    abActiveProcs(iI) = this.oBranch.aoFlowProcs(iI).bActive;
                end
    
                for iI = 1:length(abActiveProcs)
                    if abActiveProcs(iI)
                        this.oBranch.aoFlowProcs(iI).update();
                    end
                end
                
            end
        end
    end
end