function sanityCheckXML_import(tVHAB_Objects, tConvertIDs)

sError = [];
for iBranch = 1:length(tVHAB_Objects.Branch)
    tBranch = tVHAB_Objects.Branch{iBranch};
    if ~isfield(tBranch, 'SourceID')
        if isfield(tBranch, 'sCustomName') && ~isempty(tBranch.sCustomName)
            try
                sError = [sError, 'In system ', tConvertIDs.tIDtoLabel.(tBranch.ParentID), ' the branch with the name ', tBranch.sCustomName,' has no source. It targets a ', tConvertIDs.tIDtoType.(tBranch.TargetID),' called ', tConvertIDs.tIDtoLabel.(tBranch.TargetID), '\n'];
            catch
                sError = [sError, 'In system ', tConvertIDs.tIDtoLabel.(tBranch.ParentID), ' the branch with the name ', tBranch.sCustomName,' has no connected interface at all. Make sure that the arrows in draw IO actually connect with the components!', '\n'];
            end
        else
            try
                sError = [sError, 'In system ', tConvertIDs.tIDtoLabel.(tBranch.ParentID), ' the branch with the id ', tBranch.id,' has no source. It targets a ', tConvertIDs.tIDtoType.(tBranch.TargetID),' called ', tConvertIDs.tIDtoLabel.(tBranch.TargetID), '\n'];
            catch
                sError = [sError, 'In system ', tConvertIDs.tIDtoLabel.(tBranch.ParentID), ' the branch with the id ', tBranch.id,' has no connected interface at all. Make sure that the arrows in draw IO actually connect with the components!', '\n'];
            end
        end
    elseif ~isfield(tBranch, 'TargetID')
        if isfield(tBranch, 'sCustomName') && ~isempty(tBranch.sCustomName)
            try
                sError = [sError, 'In system ', tConvertIDs.tIDtoLabel.(tBranch.ParentID), ' the branch with the name ', tBranch.sCustomName,' has no target. It targets a ', tConvertIDs.tIDtoType.(tBranch.SourceID),' called ', tConvertIDs.tIDtoLabel.(tBranch.SourceID), '\n'];
            catch
                sError = [sError, 'In system ', tConvertIDs.tIDtoLabel.(tBranch.ParentID), ' the branch with the name ', tBranch.sCustomName,' has no connected interface at all. Make sure that the arrows in draw IO actually connect with the components!', '\n'];
            end
        else
            try
                sError = [sError, 'In system ', tConvertIDs.tIDtoLabel.(tBranch.ParentID), ' the branch with the id ', tBranch.id,' has no target. It comes from a ', tConvertIDs.tIDtoType.(tBranch.SourceID),' called ', tConvertIDs.tIDtoLabel.(tBranch.SourceID), '\n'];
            catch
                sError = [sError, 'In system ', tConvertIDs.tIDtoLabel.(tBranch.ParentID), ' the branch with the id ', tBranch.id,' has no connected interface at all. Make sure that the arrows in draw IO actually connect with the components!', '\n'];
            end
        end
    end 
end

% TO DO
% Add check if the subsystems still have the correct number of
% Inputs/Outputs

if ~isempty(sError)
    error(sError)
end
end