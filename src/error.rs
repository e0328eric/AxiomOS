use core::fmt::{self, Display};

use multiboot2::MbiLoadError;

#[derive(Debug)]
pub enum AxiomOsErr {
    Multiboot2Err(MbiLoadError),
    CannotGetMemoryMapTag,
    CannotGetElfSectionTag,
}

impl From<MbiLoadError> for AxiomOsErr {
    fn from(err: MbiLoadError) -> Self {
        Self::Multiboot2Err(err)
    }
}

impl Display for AxiomOsErr {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Multiboot2Err(err) => write!(f, "{:?}", err),
            Self::CannotGetMemoryMapTag => write!(f, "Memory map tag required"),
            Self::CannotGetElfSectionTag => write!(f, "Elf-sections tag required"),
        }
    }
}

pub type Result<T> = core::result::Result<T, AxiomOsErr>;
