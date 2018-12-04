classdef (Abstract) sys < base & event.source
    %SYS Represents a generic system object
    %   The class is defined as abstract, since the actual systems objects
    %   will need to incorporate domain-specific properties and methods. 
    
    properties (SetAccess = protected, GetAccess = public)
        % Name of the system
        sName;
        
        % Parent system
        oParent;
        
        % Root system. Special sys which inherits from systems.root. Does
        % not have a real oParent (references itself). Generally, special
        % system that contains additional data about the hierarchy.
        oRoot;
        
        % Child system objects in a struct
        toChildren = struct();
        
        % The names of the child systems as strings in a cell
        csChildren = {};
        
        % Number of child systems
        iChildren  = 0;
        
    end
    
    methods
        function this = sys(oParent, sName)
            % Construct the sys object
            %
            % sys parameters:
            %   oParent     - parent system
            %   sName       - name of this system
            this@base();
            
            % It MAY happen that the sys constructor is called several
            % times, if a sys derives e.g. from matter.container AND timed,
            % since both classes derive from sys and call the sys
            % constroctur explicitly. Therefore check if the parent is
            % already set and the same - if not, if other parent set, throw
            % an error!
            if ~isempty(this.oParent)
                if this.oParent ~= oParent
                    this.throw('sys', 'It seems like the sys constructor is called several times. This is ok and might happen if a class derives from two classes that both at some point derive from ''sys''. However, the parent provided at the two calls was different, and that should not happen ... parent names %s and %s', this.oParent.sName, oParent.sName);
                end
                
            % Only need to set the parent if not set yet    
            else
                this.sName = sName;
                this.setParent(oParent);
            end
        end
    end
   
    %% Methods handling the system relations - parent, child, data
    methods
        function this = setParent(this, oParent)
            % This method sets the parent object property of this class and
            % adds itself to the parent object as a child. 
            
            % Making sure our parent is actually a sys
            if ~isa(oParent, 'sys')
                this.throw('setParent', 'Parent object has to inherit from "sys"!');
            
            % Don't set if already set correctly
            elseif ~isempty(this.oParent) && oParent == this.oParent
                return;
            
            % If we are chaning the parent, we first need to remove us from
            % old parent
            elseif ~isempty(this.oParent)
                % removeChild checks if oParent is empty
                oOldParent = this.oParent;
                this.oParent = [];
                
                oOldParent.removeChild(this);
            end
            
            % Setting the oParent property
            this.oParent = oParent;
            
            % The addChild method checks if the provided object isa sys and
            % has the oParent set to itself
            this.oParent.addChild(this);
            
            % Get root system from parent
            this.oRoot = this.oParent.oRoot;
        end
        
        function this = removeChild(this, oChild)
            % Remove child. Only possible of oChild.oParent is empty!
            
            if ~isa(oChild, 'sys')
                this.throw('removeChild', 'Child object has to inherit from "sys"!');
            elseif ~this.isChild(oChild)
                this.throw('removeChild', 'Object not child of this system.');
            elseif ~isempty(oChild.oParent)
                this.throw('removeChild', 'Child object oParent is not empty.');
            end
            
            % Remove child object from the different properties
            this.toChildren = rmfield(this.toChildren, oChild.sName);
            this.csChildren{strcmp(this.csChildren, oChild.sName)} = [];
            this.iChildren = this.iChildren - 1;
        end
        
        function this = addChild(this, oChild)
            % Add a child object
            
            % Check child object type and if parent is correctly set
            if ~isa(oChild, 'sys')
                this.throw('addChild', 'Child object has to inherit from "sys"!');
            elseif oChild.oParent ~= this
                this.throw('addChild', 'Child object needs to have the oParent attribute already set to new parent!');
            end
            
            % Check if a child with that name already exists
            if isfield(this.toChildren, oChild.sName)
                % Does exist but is the same - i.e. child already there.
                if this.toChildren.(oChild.sName) == oChild
                    % Delete - re-created below as last entry in struct!
                    this.toChildren = rmfield(this.toChildren, oChild.sName);
                else
                    this.throw('addChild', 'Different child object with the same name already exists');
                end
            end
            
            % Append the child
            this.toChildren.(oChild.sName) = oChild;
            
            % Update name cache cell
            this.csChildren = fieldnames(this.toChildren);
            this.iChildren  = length(this.csChildren);
        end
        
        function oChild = getChild(this, xIndex)
            % Get child by name or position
            
            % Easiest way just try/catch ...
            try
                if ischar(xIndex)
                    oChild = this.toChildren.(xIndex);
                else
                    oChild = this.toChildren.(this.csChildren{xIndex});
                end
            catch %#ok<CTCH>
                oChild = [];
            end
        end
        
        function bIs = isChild(this, xIndex)
            % Check if child exists - param can be int, char or obj!
            
            % Object? Loop children and compare!
            if isa(xIndex, 'sys')
                
                bIs = isfield(this.toChildren, xIndex.sName) && (this.toChildren.(xIndex.sName) == xIndex);
            
            % Int or char - use getChild    
            else
                bIs = ~isempty(this.getChild(xIndex));
            end
        end
    end
end