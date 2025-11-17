function bool = compareArrays(A,B)
    if size(A,1) ~= size(B,1)
        bool = 0;
        return
    elseif size(A,2) ~= size(B,2)
        bool = 0;
        return
    end
    for i =1:size(A,1)
        for j = size(A, 2)
            if A(i, j )~= B(i,j)
                bool = 0;
                return
            end
        end
    end
    bool = 1;
end
