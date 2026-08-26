interface Searchable {
    searchKey: string;
    address: string;
    domainId: string;
    ref?: any;
    priority?: number;
}

interface VirSemanticHit {
    sourceIndex: number;
    rawScore: number;
    semanticPriority: number | null;
    domainPriority: number | null;
    itemPriority: number | null;
}

interface VirFullTextHit {
    sourceIndex: number;
    rawScore: number;
    fullTextPriority: number | null;
    documentPriority: number | null;
}

interface VirRankedCandidate {
    kind: "semantic" | "fullText";
    sourceIndex: number;
    score: number;
}

interface SearchVirProvider {
    mapDomain(domainId: string, domainData: any): Searchable[] | null;
    rankCandidates(semantic: VirSemanticHit[], fullText: VirFullTextHit[]): VirRankedCandidate[];
}

interface SearchVirConfig {
    runtimeModule: string;
    wasmUrl: string;
    packageSetUrl: string;
    mapEntry: string;
    rankEntry: string;
}

interface Window {
    versoSearchVir?: SearchVirConfig;
}
