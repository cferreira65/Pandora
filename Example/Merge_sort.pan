proc merge(var a : array of int[10], p:int, q:int, r: int) : void
    i: int;
    j : int;
    k : int;
    b : array of int[10];
    i = p;
    j = q+1;
    k = p;
    while ((i <= q) and (j <= r)) do
        if( a[i] < a[j]) then
            b[k] = a[i];
            i = i+1;
        end
        else
            b[k] = a[j]; 
            j = j+1;
        end
        k = k+1;
    end
    for (k from  p to r with k+1) do
        a[k] = b[k];
        write a[k];
    end
end

begin
    n : int;
    n = 6;
    a : array of int[n];
    a = [1,3,9,6,5,2];
    merge_sort(a,1,n);
end